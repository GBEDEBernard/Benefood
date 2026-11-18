<?php

namespace App\Services;

use App\Exceptions\DomainException;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Pipeline médias (J34) : validation stricte (mime/taille par contenu),
 * redimensionnement cover + thumbnail et encodage WebP via GD natif.
 */
class MediaService
{
    /** Taille maximale d'une image (J34 : 5 Mo). */
    public const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

    /** Taille maximale d'une vidéo produit (petit clip). */
    public const MAX_VIDEO_BYTES = 25 * 1024 * 1024;

    /** MIME autorisés pour les images (J34). */
    private const ALLOWED_IMAGE_MIME = ['image/jpeg', 'image/png', 'image/webp'];

    /** MIME autorisés pour les vidéos produit, associés à leur extension. */
    private const ALLOWED_VIDEO_MIME = [
        'video/mp4' => 'mp4',
        'application/mp4' => 'mp4',
        'video/quicktime' => 'mov',
        'video/webm' => 'webm',
    ];

    /** Couverture principale produit (J34 : 800x800). */
    private const COVER_SIZE = 800;

    /** Thumbnail produit (J34 : 400x400). */
    private const THUMB_SIZE = 400;

    public function __construct(private readonly string $disk = 'public') {}

    /**
     * Stocke une image produit optimisée (WebP couverture + thumbnail).
     *
     * @return array{path: string, thumb_path: string, mime: string, size: int}
     */
    public function storeProductImage(UploadedFile $file, string $vendorId, string $productId): array
    {
        $this->assertValidImage($file);
        $this->assertWebpSupported();

        $source = $this->openImage((string) $file->getRealPath());

        try {
            $cover = $this->encodeWebp($this->coverResize($source, self::COVER_SIZE, self::COVER_SIZE));
            $thumb = $this->encodeWebp($this->coverResize($source, self::THUMB_SIZE, self::THUMB_SIZE));
        } finally {
            imagedestroy($source);
        }

        $id = (string) Str::uuid();
        $dir = "products/{$vendorId}/{$productId}";
        $path = "{$dir}/{$id}.webp";
        $thumbPath = "{$dir}/{$id}_thumb.webp";

        $disk = Storage::disk($this->disk);
        $disk->put($path, $cover);
        $disk->put($thumbPath, $thumb);

        return [
            'path' => $path,
            'thumb_path' => $thumbPath,
            'mime' => 'image/webp',
            'size' => strlen($cover),
        ];
    }

    public function deleteProductImage(string $path): void
    {
        if ($path === '') {
            return;
        }

        $disk = Storage::disk($this->disk);
        $disk->delete($path);

        $thumb = preg_replace('/\.webp$/i', '_thumb.webp', $path);
        if (is_string($thumb) && $thumb !== $path) {
            $disk->delete($thumb);
        }
    }

    /**
     * Stocke une petite vidéo produit sur le disque public.
     *
     * @return array{path: string, mime: string, size: int}
     */
    public function storeProductVideo(UploadedFile $file, string $vendorId, string $productId): array
    {
        $mime = $this->assertValidVideo($file);

        $dir = "products/{$vendorId}/{$productId}";
        $filename = Str::uuid().'.'.self::ALLOWED_VIDEO_MIME[$mime];

        Storage::disk($this->disk)->putFileAs($dir, $file, $filename);

        return [
            'path' => "{$dir}/{$filename}",
            'mime' => $mime,
            'size' => (int) $file->getSize(),
        ];
    }

    public function deleteProductVideo(string $path): void
    {
        if ($path === '') {
            return;
        }

        Storage::disk($this->disk)->delete($path);
    }

    /**
     * Valide la vidéo par contenu et retourne son MIME détecté.
     */
    private function assertValidVideo(UploadedFile $file): string
    {
        if (! $file->isValid()) {
            throw new DomainException('media.invalid_file', 'Le fichier envoyé est invalide.', 422);
        }

        if ($file->getSize() > self::MAX_VIDEO_BYTES) {
            throw new DomainException('media.too_large', 'La vidéo ne doit pas dépasser 25 Mo.', 422);
        }

        $realPath = (string) $file->getRealPath();
        $detected = (new \finfo(FILEINFO_MIME_TYPE))->file($realPath) ?: $file->getMimeType();

        if (! isset(self::ALLOWED_VIDEO_MIME[$detected])) {
            throw new DomainException('media.invalid_mime', 'Format vidéo non autorisé (mp4, mov ou webm uniquement).', 422);
        }

        return $detected;
    }

    private function assertValidImage(UploadedFile $file): void
    {
        if (! $file->isValid()) {
            throw new DomainException('media.invalid_file', 'Le fichier envoyé est invalide.', 422);
        }

        if ($file->getSize() > self::MAX_IMAGE_BYTES) {
            throw new DomainException('media.too_large', 'L\'image ne doit pas dépasser 5 Mo.', 422);
        }

        $realPath = (string) $file->getRealPath();
        $detected = (new \finfo(FILEINFO_MIME_TYPE))->file($realPath) ?: $file->getMimeType();

        if (! in_array($detected, self::ALLOWED_IMAGE_MIME, true)) {
            throw new DomainException('media.invalid_mime', 'Format d\'image non autorisé (jpeg, png ou webp uniquement).', 422);
        }
    }

    private function assertWebpSupported(): void
    {
        if (! function_exists('imagewebp') || ! function_exists('imagecreatefromwebp')) {
            throw new DomainException(
                'media.webp_unsupported',
                'Le serveur ne supporte pas WebP. Activez GD avec le support WebP (--with-webp) ou Imagick.',
                500,
            );
        }
    }

    /**
     * Décode l'image source en ressource GD.
     */
    private function openImage(string $sourcePath): GdImage
    {
        $info = @getimagesize($sourcePath);

        if ($info === false) {
            throw new DomainException('media.unreadable', 'Image illisible.', 422);
        }

        [$width, $height, $type] = $info;

        if ($width < 1 || $height < 1) {
            throw new DomainException('media.unreadable', 'Dimensions d\'image invalides.', 422);
        }

        $source = match ($type) {
            IMAGETYPE_JPEG => function_exists('imagecreatefromjpeg') ? @imagecreatefromjpeg($sourcePath) : false,
            IMAGETYPE_PNG => function_exists('imagecreatefrompng') ? @imagecreatefrompng($sourcePath) : false,
            IMAGETYPE_WEBP => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($sourcePath) : false,
            default => false,
        };

        if (! $source instanceof GdImage) {
            throw new DomainException('media.unsupported_format', 'Format d\'image non supporté par le serveur.', 422);
        }

        if (! imageistruecolor($source)) {
            imagepalettetotruecolor($source);
        }

        imagealphablending($source, false);
        imagesavealpha($source, true);

        return $source;
    }

    /**
     * Redimensionne l'image source en couverture crop centrée.
     */
    private function coverResize(GdImage $source, int $targetWidth, int $targetHeight): GdImage
    {
        $srcWidth = imagesx($source);
        $srcHeight = imagesy($source);

        [$cropX, $cropY, $cropWidth, $cropHeight] = $this->coverCrop($srcWidth, $srcHeight, $targetWidth, $targetHeight);

        $destination = imagecreatetruecolor($targetWidth, $targetHeight);

        if ($destination === false) {
            throw new RuntimeException('Impossible de créer l\'image de destination.');
        }

        imagealphablending($destination, false);
        imagesavealpha($destination, true);
        $transparent = imagecolorallocatealpha($destination, 0, 0, 0, 127);

        if ($transparent === false) {
            imagedestroy($destination);

            throw new RuntimeException('Impossible d\'allouer la couleur transparente.');
        }

        imagefill($destination, 0, 0, $transparent);

        if (! imagecopyresampled($destination, $source, 0, 0, $cropX, $cropY, $targetWidth, $targetHeight, $cropWidth, $cropHeight)) {
            imagedestroy($destination);

            throw new RuntimeException('Impossible de redimensionner l\'image.');
        }

        return $destination;
    }

    /**
     * Encode une ressource GD en WebP (qualité 85) et libère la ressource.
     */
    private function encodeWebp(GdImage $image): string
    {
        ob_start();

        try {
            if (! imagewebp($image, null, 85)) {
                throw new RuntimeException('Échec de l\'encodage WebP.');
            }

            $blob = (string) ob_get_clean();
        } catch (Throwable $exception) {
            ob_end_clean();

            throw $exception;
        } finally {
            imagedestroy($image);
        }

        if ($blob === '') {
            throw new RuntimeException('Échec de l\'encodage WebP.');
        }

        return $blob;
    }

    /**
     * @return array{int, int, int, int} (x, y, largeur, hauteur)
     */
    private function coverCrop(int $srcWidth, int $srcHeight, int $targetWidth, int $targetHeight): array
    {
        $srcRatio = $srcWidth / max(1, $srcHeight);
        $dstRatio = $targetWidth / max(1, $targetHeight);

        if ($srcRatio > $dstRatio) {
            $cropWidth = (int) round($srcHeight * $dstRatio);
            $cropHeight = $srcHeight;
            $cropX = (int) round(($srcWidth - $cropWidth) / 2);
            $cropY = 0;
        } else {
            $cropWidth = $srcWidth;
            $cropHeight = (int) round($srcWidth / $dstRatio);
            $cropX = 0;
            $cropY = (int) round(($srcHeight - $cropHeight) / 2);
        }

        return [$cropX, $cropY, $cropWidth, $cropHeight];
    }
}
