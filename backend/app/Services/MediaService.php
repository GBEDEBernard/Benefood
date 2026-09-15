<?php

namespace App\Services;

use App\Exceptions\DomainException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Pipeline médias (J34) : validation stricte (mime/taille par contenu),
 * redimensionnement cover + thumbnail et encodage WebP via GD natif.
 */
class MediaService
{
    /** Taille maximale d'une image (J34 : 5 Mo). */
    public const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

    /** MIME autorisés pour les images (J34). */
    private const ALLOWED_IMAGE_MIME = ['image/jpeg', 'image/png', 'image/webp'];

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

        $cover = $this->resizeToWebp($file->getRealPath(), self::COVER_SIZE, self::COVER_SIZE);
        $thumb = $this->resizeToWebp($file->getRealPath(), self::THUMB_SIZE, self::THUMB_SIZE);

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

    /**
     * Redimensionne l'image source en WebP (couverture crop centrée).
     */
    private function resizeToWebp(string $sourcePath, int $targetWidth, int $targetHeight): string
    {
        $info = getimagesize($sourcePath);

        if ($info === false) {
            throw new RuntimeException('Image illisible.');
        }

        [$srcWidth, $srcHeight, $type] = $info;

        $src = match ($type) {
            IMAGETYPE_JPEG => imagecreatefromjpeg($sourcePath),
            IMAGETYPE_PNG => imagecreatefrompng($sourcePath),
            IMAGETYPE_WEBP => imagecreatefromwebp($sourcePath),
            default => throw new RuntimeException('Format d\'image non supporté.'),
        };

        if ($src === false) {
            throw new RuntimeException('Impossible de décoder l\'image.');
        }

        [$cropX, $cropY, $cropWidth, $cropHeight] = $this->coverCrop($srcWidth, $srcHeight, $targetWidth, $targetHeight);

        $dst = imagecreatetruecolor($targetWidth, $targetHeight);
        imagealphablending($dst, false);
        imagesavealpha($dst, true);
        $transparent = imagecolorallocatealpha($dst, 0, 0, 0, 127);
        imagefill($dst, 0, 0, $transparent);
        imagecopyresampled($dst, $src, 0, 0, $cropX, $cropY, $targetWidth, $targetHeight, $cropWidth, $cropHeight);

        ob_start();
        imagewebp($dst, null, 85);
        $blob = (string) ob_get_clean();

        imagedestroy($src);
        imagedestroy($dst);

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
