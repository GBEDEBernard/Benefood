<?php

namespace App\Enums;

enum NotificationTemplateChannel: string
{
    case Push = 'push';
    case Email = 'email';
    case Sms = 'sms';
}
