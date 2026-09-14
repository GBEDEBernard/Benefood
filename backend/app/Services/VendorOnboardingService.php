<?php

namespace App\Services;

use App\Enums\VendorDocumentStatus;
use App\Enums\VendorDocumentType;
use App\Enums\VendorStatus;
use App\Exceptions\DomainException;
use App\Models\User;
use App\Models\Vendor;
use App\Models\VendorDocument;
use App\Support\Phone;
use Illuminate\Http\UploadedFile;

/**
 * Onboarding vendeur, soumission de documents et récupération du statut (J46).
 */
class VendorOnboardingService
{
    public function __construct(private readonly AuthService $auth) {}

    public function onboard(User $user, array $data): Vendor
    {
        if ($user->vendor()->exists()) {
            throw new DomainException('vendor.already_onboarded', 'Un profil vendeur existe déjà pour ce compte.', 409);
        }

        $vendor = Vendor::create([
            'user_id' => $user->id,
            'business_name' => $data['business_name'],
            'legal_name' => $data['legal_name'] ?? null,
            'ifu' => $data['ifu'] ?? null,
            'description' => $data['description'] ?? null,
            'phone' => Phone::normalize($data['phone']),
            'email' => $data['email'] ?? null,
            'city' => $data['city'] ?? null,
            'address' => $data['address'] ?? null,
            'status' => VendorStatus::Registered->value,
        ]);

        $this->recordHistory($vendor, null, VendorStatus::Registered, actorType: 'user', actorId: $user->id);

        $this->auth->assignRole($user, 'vendor', isActive: false);

        return $vendor->fresh();
    }

    public function submitDocument(
        Vendor $vendor,
        UploadedFile $file,
        string $documentType,
        User $actor,
    ): VendorDocument {
        $docTypeEnum = VendorDocumentType::tryFrom($documentType);

        if ($docTypeEnum === null) {
            throw new DomainException('vendor.invalid_document_type', "Le type « {$documentType} » n'est pas reconnu.", 422);
        }

        $filename = $docTypeEnum->value.'-'.uniqid('', true).'.'.$file->getClientOriginalExtension();
        $path = $file->storeAs("vendor-documents/{$vendor->id}", $filename, 'private');

        $document = $vendor->documents()->create([
            'type' => $docTypeEnum->value,
            'file_path' => $path,
            'status' => VendorDocumentStatus::Submitted->value,
            'submitted_by' => $actor->id,
        ]);

        if ($vendor->status === VendorStatus::Registered->value) {
            $vendor->update(['status' => VendorStatus::PendingVerification->value]);
            $this->recordHistory($vendor, VendorStatus::Registered, VendorStatus::PendingVerification, actorType: 'user', actorId: $actor->id);
        }

        return $document;
    }

    public function getStatus(Vendor $vendor): array
    {
        $vendor->load('documents');

        return [
            'vendor' => $vendor->toArray(),
            'documents' => $vendor->documents->map(fn (VendorDocument $document) => [
                'id' => $document->id,
                'type' => $document->type,
                'status' => $document->status,
                'reason' => $document->reason,
                'created_at' => $document->created_at?->toIso8601String(),
            ])->values(),
        ];
    }

    public function recordHistory(
        Vendor $vendor,
        ?VendorStatus $from,
        VendorStatus $to,
        ?string $reason = null,
        ?string $actorType = null,
        ?string $actorId = null,
    ): void {
        $vendor->statusHistory()->create([
            'from_status' => $from?->value,
            'to_status' => $to->value,
            'reason' => $reason,
            'actor_type' => $actorType,
            'actor_id' => $actorId,
        ]);

        if ($to === VendorStatus::Active && $vendor->approved_at === null) {
            $vendor->update(['approved_at' => now()]);
        }
        if ($to === VendorStatus::Closed && $vendor->closed_at === null) {
            $vendor->update(['closed_at' => now()]);
        }
    }
}
