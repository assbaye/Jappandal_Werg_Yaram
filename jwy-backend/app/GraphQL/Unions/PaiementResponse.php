<?php

namespace App\GraphQL\Unions;

use GraphQL\Type\Definition\ResolveInfo;
use GraphQL\Type\Definition\Type;
use Nuwave\Lighthouse\Schema\TypeRegistry;
use Nuwave\Lighthouse\Support\Contracts\GraphQLContext;

/**
 * Résout le type concret de PaiementResponse à partir de la clé `__type`
 * renvoyée par PaymentService.
 */
class PaiementResponse
{
    public function __construct(private TypeRegistry $typeRegistry) {}

    public function __invoke(mixed $rootValue, GraphQLContext $context, ResolveInfo $resolveInfo): Type
    {
        return $this->typeRegistry->get($rootValue['__type'] ?? 'PaiementMobileResponse');
    }
}
