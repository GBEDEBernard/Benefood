<?php

namespace App\Enums;

enum PayoutBatchStatus: string
{
    /** Lot en cours : retraits en attente d'exécution. */
    case Processing = 'processing';

    /** Tous les retraits du lot ont été versés. */
    case Executed = 'executed';

    /** Mélange de retraits versés et en échec. */
    case PartiallyFailed = 'partially_failed';

    /** Tous les retraits du lot ont échoué. */
    case Failed = 'failed';
}
