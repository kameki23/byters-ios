import Foundation

// MARK: - ViewModel Architecture Guide
//
// 新しい機能のViewModelはこのディレクトリに配置してください。
//
// 既存のViewModelは各Viewファイルに埋め込まれています:
// - Views/JobSeeker/ ... HomeViewModel, JobSearchViewModel, etc.
// - Views/Employer/EmployerViews.swift ... EmployerDashboardViewModel, etc.
// - Views/Admin/AdminViews.swift ... AdminDashboardViewModel, etc.
//
// 新規ViewModel配置先:
// - ViewModels/ReviewViewModel.swift
// - ViewModels/CancellationViewModel.swift
// - ViewModels/TaxDocumentViewModel.swift
// - ViewModels/RecommendationViewModel.swift
// - ViewModels/EmployerFollowViewModel.swift
//
// 将来的に既存ViewModelもこのディレクトリに移行予定。

// MARK: - Base ViewModel Protocol

@MainActor
protocol BaseViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    func loadData() async
}

extension BaseViewModel {
    func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            errorMessage = apiError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
