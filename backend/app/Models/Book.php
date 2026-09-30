<?php

namespace App\Models;

use Database\Factories\BookFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name'])]
class Book extends Model
{
    /** @use HasFactory<BookFactory> */
    use HasFactory;

    /**
     * The user who owns this book.
     *
     * Ownership is what the upload endpoint checks: the specification requires the
     * server to verify a book before storing anything against it.
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Every stored snapshot of this book's fiscal years.
     */
    public function backupRevisions(): HasMany
    {
        return $this->hasMany(BackupRevision::class);
    }
}
