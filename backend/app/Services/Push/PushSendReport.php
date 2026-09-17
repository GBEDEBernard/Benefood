<?php

namespace App\Services\Push;

/**
 * Résultat agrégé d'un envoi push sur un lot de tokens (J126).
 */
final class PushSendReport
{
    /**
     * @param  list<string>  $successes
     * @param  list<string>  $invalid
     * @param  list<string>  $unknown
     * @param  array<string, string>  $failures
     */
    public function __construct(
        private readonly array $successes = [],
        private readonly array $invalid = [],
        private readonly array $unknown = [],
        private readonly array $failures = [],
    ) {}

    /**
     * @return list<string>
     */
    public function successes(): array
    {
        return $this->successes;
    }

    /**
     * @return list<string>
     */
    public function invalidTokens(): array
    {
        return $this->invalid;
    }

    /**
     * @return list<string>
     */
    public function unknownTokens(): array
    {
        return $this->unknown;
    }

    /**
     * @return array<string, string>
     */
    public function failures(): array
    {
        return $this->failures;
    }

    public function merge(self $other): self
    {
        return new self(
            successes: [...$this->successes, ...$other->successes],
            invalid: [...$this->invalid, ...$other->invalid],
            unknown: [...$this->unknown, ...$other->unknown],
            failures: [...$this->failures, ...$other->failures],
        );
    }
}
