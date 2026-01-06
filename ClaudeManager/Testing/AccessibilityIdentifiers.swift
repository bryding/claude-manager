enum AccessibilityIdentifiers {
    // MARK: - MainView

    enum MainView {
        static let mainView = "mainView"
        static let tabBar = "tabBar"
        static let contentArea = "contentArea"
    }

    // MARK: - TabBar

    enum TabBar {
        static let addTabButton = "addTabButton"

        static func tab(_ id: String) -> String {
            "tab_\(id)"
        }

        static func tabCloseButton(_ id: String) -> String {
            "tabCloseButton_\(id)"
        }

        static func tabStatusDot(_ id: String) -> String {
            "tabStatusDot_\(id)"
        }
    }

    // MARK: - SetupView

    enum SetupView {
        static let setupView = "setupView"
        static let selectFolderButton = "selectFolderButton"
        static let projectPathDisplay = "projectPathDisplay"
        static let featureDescriptionEditor = "featureDescriptionEditor"
        static let attachedImagesView = "attachedImagesView"
        static let existingPlanBanner = "existingPlanBanner"
        static let useExistingPlanButton = "useExistingPlanButton"
        static let dismissPlanButton = "dismissPlanButton"
        static let startButton = "startButton"
    }

    // MARK: - ExecutionView

    enum ExecutionView {
        static let executionView = "executionView"
        static let phaseIndicator = "phaseIndicator"
        static let progressBar = "progressBar"
        static let progressPercentage = "progressPercentage"
    }

    // MARK: - ControlsView

    enum ControlsView {
        static let controlsView = "controlsView"
        static let pauseButton = "pauseButton"
        static let resumeButton = "resumeButton"
        static let stopButton = "stopButton"
        static let continueButton = "continueButton"
        static let startButton = "startButton"
        static let elapsedTimeDisplay = "elapsedTimeDisplay"
        static let costDisplay = "costDisplay"
        static let stopConfirmationDialog = "stopConfirmationDialog"
    }

    // MARK: - UserQuestionView

    enum UserQuestionView {
        static let userQuestionView = "userQuestionView"
        static let questionHeader = "questionHeader"
        static let questionText = "questionText"
        static let optionsSection = "optionsSection"
        static let freeformTextEditor = "freeformTextEditor"
        static let skipButton = "skipButton"
        static let submitButton = "submitButton"

        static func option(_ index: Int) -> String {
            "option_\(index)"
        }
    }

    // MARK: - LogView

    enum LogView {
        static let logView = "logView"
        static let logSearchField = "logSearchField"
        static let logFilterPicker = "logFilterPicker"
        static let autoScrollToggle = "autoScrollToggle"
    }

    // MARK: - TaskListView

    enum TaskListView {
        static let taskListView = "taskListView"

        static func task(_ number: Int) -> String {
            "task_\(number)"
        }

        static func taskStatus(_ number: Int) -> String {
            "taskStatus_\(number)"
        }
    }
}
