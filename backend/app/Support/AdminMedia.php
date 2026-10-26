<?php

namespace App\Support;

final class AdminMedia
{
    private const AVATAR_TONES = ['sage', 'amber', 'clay', 'mint', 'sand', 'slate'];

    public static function url(?string $path): ?string
    {
        if ($path === null) {
            return null;
        }

        $path = trim($path);

        if ($path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        $path = ltrim($path, '/');

        if (str_starts_with($path, 'storage/')) {
            $path = substr($path, strlen('storage/'));
        }

        return '/storage/'.$path;
    }

    public static function initials(?string $name): string
    {
        $name = trim((string) $name);

        if ($name === '') {
            return '?';
        }

        $parts = preg_split('/\s+/u', $name) ?: [];

        $initials = collect($parts)
            ->filter()
            ->take(2)
            ->map(fn (string $part): string => mb_strtoupper(mb_substr($part, 0, 1)))
            ->implode('');

        if ($initials === '') {
            $initials = mb_strtoupper(mb_substr($name, 0, 2));
        }

        return $initials;
    }

    public static function tone(?string $seed): string
    {
        $seed = trim((string) $seed);

        if ($seed === '') {
            return self::AVATAR_TONES[0];
        }

        $index = (int) (sprintf('%u', crc32($seed)) % count(self::AVATAR_TONES));

        return self::AVATAR_TONES[$index];
    }
}
