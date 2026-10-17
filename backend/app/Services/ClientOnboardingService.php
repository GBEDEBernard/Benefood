<?php

namespace App\Services;

use App\Enums\ClientDocumentStatus;
use App\Enums\ClientDocumentType;
use App\Enums\ClientStatus;
use App\Exceptions\DomainException;
use App\Models\ClientDocument;
use App\Models\ClientProfile;
use App\Models\User;
use Illuminate\Http\UploadedFile;

/**
 * Onboarding du compte client (J19) : coordonnées + pièces justificatives
 * (carte CIP/biométrique, justificatif de domicile) avant la première commande.
 */
class ClientOnboardingService
{
    /**
     * Types de documents exigés pour activer le compte client.
     *
     * @var array<int, string>
     */
    public const REQUIRED_DOCUMENTS = [
        ClientDocumentType::IdCard->value,
        ClientDocumentType::ProofOfAddress->value,
    ];

    public function onboard(User $user, array $data): ClientProfile
    {
        $profile = $user->clientProfile()->first();

        if ($profile === null) {
            $profile = ClientProfile::create([
                'user_id' => $user->id,
                'status' => ClientStatus::Pending->value,
                'full_name' => $data['full_name'] ?? $user->name,
                'phone' => $data['phone'] ?? $user->phone,
                'address' => $data['address'] ?? null,
                'city' => $data['city'] ?? null,
                'area' => $data['area'] ?? null,
            ]);
        } else {
            $profile->update(array_filter([
                'full_name' => $data['full_name'] ?? null,
                'phone' => $data['phone'] ?? null,
                'address' => $data['address'] ?? null,
                'city' => $data['city'] ?? null,
                'area' => $data['area'] ?? null,
            ], fn ($value) => $value !== null));
        }

        return $this->syncActivation($profile->fresh());
    }

    public function submitDocument(ClientProfile $profile, UploadedFile $file, string $documentType): ClientDocument
    {
        $docType = ClientDocumentType::tryFrom($documentType);

        if ($docType === null) {
            throw new DomainException('client.invalid_document_type', "Le type « {$documentType} » n'est pas reconnu.", 422);
        }

        $filename = $docType->value.'-'.uniqid('', true).'.'.$file->getClientOriginalExtension();
        $path = $file->storeAs("client-documents/{$profile->id}", $filename, 'private');

        $document = $profile->documents()->create([
            'type' => $docType->value,
            'file_path' => $path,
            'status' => ClientDocumentStatus::Submitted->value,
        ]);

        $this->syncActivation($profile->fresh());

        return $document;
    }

    /**
     * Active le compte client dès que tous les documents requis sont transmis.
     */
    private function syncActivation(ClientProfile $profile): ClientProfile
    {
        $submitted = $profile->documents()->pluck('type')->all();
        $complete = empty(array_diff(self::REQUIRED_DOCUMENTS, $submitted));

        if ($complete && $profile->status === ClientStatus::Pending->value) {
            $profile->update(['status' => ClientStatus::Active->value]);
            $profile = $profile->fresh();
        }

        return $profile;
    }

    public function getStatus(ClientProfile $profile): array
    {
        $profile->load('documents');

        $submitted = $profile->documents->pluck('type')->all();

        return [
            'profile' => [
                'id' => $profile->id,
                'user_id' => $profile->user_id,
                'status' => $profile->status,
                'full_name' => $profile->full_name,
                'phone' => $profile->phone,
                'address' => $profile->address,
                'city' => $profile->city,
                'area' => $profile->area,
                'created_at' => $profile->created_at?->toIso8601String(),
            ],
            'documents' => $profile->documents->map(fn (ClientDocument $document) => [
                'id' => $document->id,
                'type' => $document->type,
                'status' => $document->status,
                'reason' => $document->reason,
                'created_at' => $document->created_at?->toIso8601String(),
            ])->values(),
            'required' => self::REQUIRED_DOCUMENTS,
            'completed' => empty(array_diff(self::REQUIRED_DOCUMENTS, $submitted)),
        ];
    }
}
