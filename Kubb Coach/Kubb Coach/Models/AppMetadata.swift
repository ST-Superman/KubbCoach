// AppMetadata.swift
// Small app-wide metadata record. Singleton-ish — only one instance ever
// inserted, created on first launch under SchemaV14.
//
// Purpose:
//   1. Forensic record of the most recent migration the store has gone
//      through. Helps diagnose "permanently unrecoverable" SwiftData
//      states in the future by giving us evidence of which version the
//      store last reached intact.
//   2. Differentiates SchemaV14's checksum from SchemaV13 (which has the
//      same set of model types). SwiftData computes version checksums
//      from the model-type list; without a new model type V14 would be
//      identical to V13 and SwiftData would throw a duplicate-checksum
//      error at launch.
//
// Adding this model is the canonical way to advance the schema version
// when only @Model field additions have happened on existing types —
// without it, lightweight migration cannot kick in for users updating
// from 1.x because the V13 store's recorded checksum no longer matches
// what SwiftData computes today.
//
// NOT synced to CloudKit. Local-only.

import SwiftData
import Foundation

@Model
final class AppMetadata {
    /// Schema-version string the store was last successfully migrated to.
    /// Useful when investigating migration failures across future versions.
    var lastSchemaVersion: String

    /// Date this record was created — corresponds to first launch on V14
    /// or later. Approximates the user's "v2.0 first-launch date."
    var firstLaunchedAt: Date

    /// Free-form notes that future migrations can write to for diagnostic
    /// breadcrumbs (e.g. "v2.0 migration succeeded normally"). Optional.
    var migrationNotes: String?

    init(
        lastSchemaVersion: String = "14.0.0",
        firstLaunchedAt: Date = Date(),
        migrationNotes: String? = nil
    ) {
        self.lastSchemaVersion = lastSchemaVersion
        self.firstLaunchedAt = firstLaunchedAt
        self.migrationNotes = migrationNotes
    }
}
