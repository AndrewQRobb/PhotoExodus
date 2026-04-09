import Foundation
import SwiftUI
import PhotoExodusCore

/// Main view model driving the PhotoExodus UI.
@MainActor
@Observable
final class AppViewModel {

    // MARK: - Navigation State

    enum Screen {
        case setup
        case processing
        case conflictReview
        case summary
    }
    var currentScreen: Screen = .setup

    // MARK: - Setup

    var inputURL: URL?
    var outputURL: URL?
    var removeEditedCopies = true

    var canStart: Bool {
        inputURL != nil && outputURL != nil
    }

    // MARK: - Processing

    var currentStage = ""
    var stageCompleted = 0
    var stageTotal = 0
    var currentFile: String?

    // MARK: - Conflict Review

    var pendingConflict: MetadataConflict?
    private var conflictContinuation: CheckedContinuation<MetadataConflict.Resolution, Never>?

    // MARK: - Summary

    var result: ProcessingResult?

    // MARK: - Task Management

    private var processingTask: Task<Void, Never>?

    var isProcessing: Bool {
        processingTask != nil
    }

    // MARK: - Actions

    func startProcessing() {
        guard let input = inputURL, let output = outputURL else { return }

        let options = ProcessingOptions(
            inputURL: input,
            outputURL: output,
            removeEditedCopies: removeEditedCopies
        )

        processingTask = Task {
            currentScreen = .processing

            do {
                let processingResult = try await ProcessingEngine.run(
                    options: options,
                    onProgress: { [weak self] progress in
                        await MainActor.run {
                            self?.currentStage = progress.stage
                            self?.stageCompleted = progress.completed
                            self?.stageTotal = progress.total
                            self?.currentFile = progress.currentFile
                        }
                    },
                    onConflict: { [weak self] conflict in
                        await self?.presentConflict(conflict) ?? .useJSON
                    }
                )

                self.result = processingResult
                self.currentScreen = .summary
            } catch is CancellationError {
                self.currentScreen = .setup
            } catch {
                // Surface error as a failed result
                self.result = ProcessingResult(
                    totalScanned: 0, duplicatesRemoved: 0, editedCopiesRemoved: 0,
                    conflictsResolved: 0, filesConverted: 0, successfullyMoved: 0,
                    dateUnknownCount: 0,
                    failures: [ProcessingResult.FailureRecord(
                        sourceURL: input, stage: "Pipeline", reason: error.localizedDescription
                    )]
                )
                self.currentScreen = .summary
            }

            self.processingTask = nil
        }
    }

    func cancelProcessing() {
        // Resume any pending continuation to avoid leak
        conflictContinuation?.resume(returning: .skip)
        conflictContinuation = nil
        pendingConflict = nil
        processingTask?.cancel()
        processingTask = nil
        currentScreen = .setup
    }

    func resolveConflict(_ resolution: MetadataConflict.Resolution) {
        conflictContinuation?.resume(returning: resolution)
        conflictContinuation = nil
        pendingConflict = nil
        currentScreen = .processing
    }

    func reset() {
        currentScreen = .setup
        result = nil
        currentStage = ""
        stageCompleted = 0
        stageTotal = 0
        currentFile = nil
    }

    // MARK: - Private

    /// Present a conflict to the user and suspend until they resolve it.
    private func presentConflict(_ conflict: MetadataConflict) async -> MetadataConflict.Resolution {
        pendingConflict = conflict
        currentScreen = .conflictReview

        return await withCheckedContinuation { continuation in
            self.conflictContinuation = continuation
        }
    }
}
