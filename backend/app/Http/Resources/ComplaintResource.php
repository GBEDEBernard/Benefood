<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ComplaintResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_id' => $this->order_id,
            'order' => $this->whenLoaded('order', fn () => [
                'id' => $this->order->id,
                'reference' => $this->order->reference,
                'status' => $this->order->status?->value,
            ]),
            'type' => $this->type,
            'subject' => $this->subject,
            'description' => $this->description,
            'status' => $this->status?->value,
            'resolution' => $this->resolution,
            'messages' => $this->whenLoaded('messages', fn () => $this->messages->map(fn ($message) => [
                'id' => $message->id,
                'sender_type' => $message->sender_type,
                'message' => $message->message,
                'created_at' => $message->created_at?->toIso8601String(),
            ])->values()),
            'closed_at' => $this->closed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
