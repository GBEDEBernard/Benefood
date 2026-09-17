<?php

namespace App\Services\Push;

/**
 * Message push à transmettre à un transport FCM (J126).
 */
final readonly class PushMessage
{
    /**
     * @param  array<string, mixed>  $data
     */
    public function __construct(
        public string $title,
        public string $body,
        public array $data = [],
    ) {}

    /**
     * Les données FCM doivent être des chaînes.
     *
     * @return array<string, string>
     */
    public function dataForTransport(): array
    {
        return array_map(
            static fn (mixed $value): string => (string) $value,
            $this->data,
        );
    }
}
