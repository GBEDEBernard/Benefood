<?php

namespace Tests\Unit;

use App\Support\Phone;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class PhoneTest extends TestCase
{
    public static function validNumbers(): array
    {
        return [
            ['+22996000000', '96000000'],
            ['22996000000', '96000000'],
            ['096000000', '96000000'],
            ['96000000', '96000000'],
            [' 9600 00 00 ', '96000000'],
        ];
    }

    public static function invalidNumbers(): array
    {
        return [
            ['+229129013653'],
            ['+2299600000'],
            [''],
            ['abc'],
        ];
    }

    #[DataProvider('validNumbers')]
    public function test_it_extracts_the_national_number(string $input, string $expected): void
    {
        $this->assertSame($expected, Phone::local($input));
        $this->assertTrue(Phone::isValid($input));
    }

    #[DataProvider('invalidNumbers')]
    public function test_it_rejects_malformed_numbers(string $input): void
    {
        $this->assertNull(Phone::local($input));
        $this->assertFalse(Phone::isValid($input));
    }

    public function test_normalize_prefixes_the_country_code(): void
    {
        $this->assertSame('+22996000000', Phone::normalize('96000000'));
        $this->assertSame('+22996000000', Phone::normalize('+229 96 00 00 00'));
    }
}
