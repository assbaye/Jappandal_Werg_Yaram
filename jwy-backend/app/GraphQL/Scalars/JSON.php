<?php

namespace App\GraphQL\Scalars;

use GraphQL\Error\Error;
use GraphQL\Language\AST\Node;
use GraphQL\Type\Definition\ScalarType;
use GraphQL\Utils\Utils;

class JSON extends ScalarType
{
    public string $name = 'JSON';

    public ?string $description = 'Arbitrary JSON value.';

    public function serialize(mixed $value): mixed
    {
        return $value;
    }

    public function parseValue(mixed $value): mixed
    {
        return $value;
    }

    public function parseLiteral(Node $valueNode, ?array $variables = null): mixed
    {
        throw new Error('JSON cannot be parsed from literal: ' . Utils::printSafe($valueNode));
    }
}
