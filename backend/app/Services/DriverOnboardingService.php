<?php

namespace App\Services;

use App\Enums\DriverDocumentStatus;
use App\Enums\DriverDocumentType;
use App\Enums\DriverStatus;
use App\Enums\DriverType;
use App\Enums\UserStatus;
use App\Exceptions\DomainException;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\User;
use App\Support\Phone;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;

/**
 * Onboarding livreur indépendant (J47), compte interne (J48) et récupération de statut.
 */
class DriverOnboardingService
{
    public function __construct(private readonly AuthService $auth) {}

    public function candidacy(User $user, array $data): DriverProfile
    {
        if ($user->driverProfile()->exists()) {
            throw new DomainException('driver.already_onboarded', 'Un profil livreur existe déjà pour ce compte.', 409);
        }

        $profile = DriverProfile::create([
            'user_id' => $user->id,
            'type' => DriverType::Independent->value,
            'status' => DriverStatus::Candidate->value,
            'vehicle' => $data['vehicle'] ?? null,
        ]);

        $this->recordHistory($profile, null, DriverStatus::Candidate, actorType: 'user', actorId: $user->id);

        $this->auth->assignRole($user, 'driver-independent', isActive: false);

        return $profile->fresh();
    }

    public function submitDocument(DriverProfile $profile, UploadedFile $file, string $documentType, User $actor): DriverDocument
    {
        $docTypeEnum = DriverDocumentType::tryFrom($documentType);

        if ($docTypeEnum === null) {
            throw new DomainException('driver.invalid_document_type', "Le type « {$documentType} » n'est pas reconnu.", 422);
        }

        $filename = $docTypeEnum->value.'-'.uniqid('', true).'.'.$file->getClientOriginalExtension();
        $path = $file->storeAs("driver-documents/{$profile->id}", $filename, 'private');

        $document = $profile->documents()->create([
            'type' => $docTypeEnum->value,
            'file_path' => $path,
            'status' => DriverDocumentStatus::Submitted->value,
        ]);

        if ($profile->status === DriverStatus::Candidate->value) {
            $profile->update(['status' => DriverStatus::PendingValidation->value]);
            $this->recordHistory($profile, DriverStatus::Candidate, DriverStatus::PendingValidation, actorType: 'user', actorId: $actor->id);
        }

        return $document;
    }

    public function createInternal(User $creator, array $data): array
    {
        $phone = Phone::normalize($data['phone']);

        if (User::where('phone', $phone)->exists()) {
            throw new DomainException('driver.phone_taken', 'Ce numéro de téléphone est déjà utilisé.', 409);
        }

        $password = $data['password'] ?? Str::random(12);

        $user = User::create([
            'name' => $data['name'],
            'phone' => $phone,
            'password' => $password,
            'status' => UserStatus::Active->value,
        ]);

        $profile = DriverProfile::create([
            'user_id' => $user->id,
            'type' => DriverType::Beninfood->value,
            'status' => DriverStatus::Validated->value,
            'vehicle' => $data['vehicle'] ?? null,
        ]);

        $this->recordHistory($profile, null, DriverStatus::Validated, actorType: 'internal', actorId: $creator->id);

        $this->auth->assignRole($user, 'driver-beninfood', isActive: false);

        return [
            'profile' => $profile->fresh(),
            'initial_password' => $password,
        ];
    }

    public function getStatus(DriverProfile $profile): array
    {
        $profile->load('documents');

        return [
            'profile' => [
                'id' => $profile->id,
                'user_id' => $profile->user_id,
                'type' => $profile->type,
                'status' => $profile->status,
                'vehicle' => $profile->vehicle,
                'available' => $profile->available,
                'rating' => $profile->rating,
                'created_at' => $profile->created_at?->toIso8601String(),
            ],
            'documents' => $profile->documents->map(fn (DriverDocument $document) => [
                'id' => $document->id,
                'type' => $document->type,
                'status' => $document->status,
                'reason' => $document->reason,
                'created_at' => $document->created_at?->toIso8601String(),
            ])->values(),
        ];
    }

    public function recordHistory(
        DriverProfile $profile,
        ?DriverStatus $from,
        DriverStatus $to,
        ?string $reason = null,
        ?string $actorType = null,
        ?string $actorId = null,
    ): void {
        $profile->statusHistory()->create([
            'from_status' => $from?->value,
            'to_status' => $to->value,
            'reason' => $reason,
            'actor_type' => $actorType,
            'actor_id' => $actorId,
        ]);

        if ($to === DriverStatus::Active && $profile->available === false) {
            $profile->update(['available' => false]);
        }
    }
}
