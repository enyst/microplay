import Foundation

/// Comprehensive settings model for the OpenHands Mac client
/// Matches the structure of config.template.toml from the backend
public struct Settings: Codable, Equatable {
    // Client-specific settings (not in backend config)
    public var client: ClientSettings
    
    // Core settings from config.template.toml
    public var core: CoreSettings
    
    // LLM settings from config.template.toml
    public var llm: LLMSettings
    
    // Agent settings from config.template.toml
    public var agent: AgentSettings
    
    // Sandbox settings from config.template.toml
    public var sandbox: SandboxSettings
    
    // Security settings from config.template.toml
    public var security: SecuritySettings
    
    // Condenser settings from config.template.toml
    public var condenser: CondenserSettings
    
    public init(
        client: ClientSettings = ClientSettings(),
        core: CoreSettings = CoreSettings(),
        llm: LLMSettings = LLMSettings(),
        agent: AgentSettings = AgentSettings(),
        sandbox: SandboxSettings = SandboxSettings(),
        security: SecuritySettings = SecuritySettings(),
        condenser: CondenserSettings = CondenserSettings()
    ) {
        self.client = client
        self.core = core
        self.llm = llm
        self.agent = agent
        self.sandbox = sandbox
        self.security = security
        self.condenser = condenser
    }
}

/// Client-specific settings (not in backend config)
public struct ClientSettings: Codable, Equatable {
    // Backend connection settings
    public var backend: BackendSettings
    
    // UI settings
    public var ui: UISettings
    
    // File explorer settings
    public var fileExplorer: FileExplorerSettings
    
    // Conversation settings
    public var conversation: ConversationSettings
    
    public init(
        backend: BackendSettings = BackendSettings(backendHost: "localhost", backendPort: 8000, useTLS: false),
        ui: UISettings = UISettings(),
        fileExplorer: FileExplorerSettings = FileExplorerSettings(),
        conversation: ConversationSettings = ConversationSettings()
    ) {
        self.backend = backend
        self.ui = ui
        self.fileExplorer = fileExplorer
        self.conversation = conversation
    }
}

/// UI-specific settings
public struct UISettings: Codable, Equatable {
    // Theme settings
    public var theme: ThemeType
    
    // Font settings
    public var fontSize: Int
    public var fontFamily: String
    
    // Layout settings
    public var showFileExplorer: Bool
    public var splitPaneRatio: Double
    
    // Accessibility settings
    public var highContrast: Bool
    public var reduceMotion: Bool
    
    public init(
        theme: ThemeType = .system,
        fontSize: Int = 14,
        fontFamily: String = "SF Pro",
        showFileExplorer: Bool = true,
        splitPaneRatio: Double = 0.3,
        highContrast: Bool = false,
        reduceMotion: Bool = false
    ) {
        self.theme = theme
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.showFileExplorer = showFileExplorer
        self.splitPaneRatio = splitPaneRatio
        self.highContrast = highContrast
        self.reduceMotion = reduceMotion
    }
    
    public enum ThemeType: String, Codable {
        case light
        case dark
        case system
    }
}

/// Conversation-specific settings
public struct ConversationSettings: Codable, Equatable {
    // History settings
    public var maxConversationHistory: Int
    public var autoSaveConversations: Bool
    public var conversationSavePath: String?
    
    // Display settings
    public var showTimestamps: Bool
    public var groupConsecutiveMessages: Bool
    
    public init(
        maxConversationHistory: Int = 50,
        autoSaveConversations: Bool = true,
        conversationSavePath: String? = nil,
        showTimestamps: Bool = true,
        groupConsecutiveMessages: Bool = true
    ) {
        self.maxConversationHistory = maxConversationHistory
        self.autoSaveConversations = autoSaveConversations
        self.conversationSavePath = conversationSavePath
        self.showTimestamps = showTimestamps
        self.groupConsecutiveMessages = groupConsecutiveMessages
    }
}

/// File explorer settings
public struct FileExplorerSettings: Codable, Equatable {
    // Display settings
    public var showHiddenFiles: Bool
    public var defaultExpandedDepth: Int
    
    // Filter settings
    public var excludedExtensions: [String]
    public var excludedDirectories: [String]
    
    public init(
        showHiddenFiles: Bool = false,
        defaultExpandedDepth: Int = 1,
        excludedExtensions: [String] = [".git", ".DS_Store"],
        excludedDirectories: [String] = [".git", "node_modules", ".venv"]
    ) {
        self.showHiddenFiles = showHiddenFiles
        self.defaultExpandedDepth = defaultExpandedDepth
        self.excludedExtensions = excludedExtensions
        self.excludedDirectories = excludedDirectories
    }
}

/// Core settings from config.template.toml
public struct CoreSettings: Codable, Equatable {
    // API keys
    public var e2bApiKey: String?
    public var modalApiTokenId: String?
    public var modalApiTokenSecret: String?
    public var daytonaApiKey: String?
    public var daytonaTarget: String?
    
    // Workspace settings
    public var workspaceBase: String
    public var cacheDir: String?
    public var workspaceMountPath: String?
    public var workspaceMountPathInSandbox: String?
    public var workspaceMountRewrite: String?
    
    // File store settings
    public var fileStorePath: String?
    public var fileStore: String?
    public var fileUploadsAllowedExtensions: [String]?
    public var fileUploadsMaxFileSizeMb: Int?
    public var fileUploadsRestrictFileTypes: Bool?
    
    // Runtime settings
    public var reasoningEffort: String?
    public var debug: Bool?
    public var disableColor: Bool?
    public var enableCliSession: Bool?
    public var saveTrajectoryPath: String?
    public var replayTrajectoryPath: String?
    public var maxBudgetPerTask: Double?
    public var maxIterations: Int?
    public var runAsOpenhands: Bool?
    public var runtime: String?
    public var defaultAgent: String?
    public var jwtSecret: String?
    public var enableDefaultCondenser: Bool?
    
    public init(
        e2bApiKey: String? = nil,
        modalApiTokenId: String? = nil,
        modalApiTokenSecret: String? = nil,
        daytonaApiKey: String? = nil,
        daytonaTarget: String? = nil,
        workspaceBase: String = "./workspace",
        cacheDir: String? = nil,
        workspaceMountPath: String? = nil,
        workspaceMountPathInSandbox: String? = nil,
        workspaceMountRewrite: String? = nil,
        fileStorePath: String? = nil,
        fileStore: String? = nil,
        fileUploadsAllowedExtensions: [String]? = nil,
        fileUploadsMaxFileSizeMb: Int? = nil,
        fileUploadsRestrictFileTypes: Bool? = nil,
        reasoningEffort: String? = nil,
        debug: Bool? = nil,
        disableColor: Bool? = nil,
        enableCliSession: Bool? = nil,
        saveTrajectoryPath: String? = nil,
        replayTrajectoryPath: String? = nil,
        maxBudgetPerTask: Double? = nil,
        maxIterations: Int? = nil,
        runAsOpenhands: Bool? = nil,
        runtime: String? = nil,
        defaultAgent: String? = nil,
        jwtSecret: String? = nil,
        enableDefaultCondenser: Bool? = nil
    ) {
        self.e2bApiKey = e2bApiKey
        self.modalApiTokenId = modalApiTokenId
        self.modalApiTokenSecret = modalApiTokenSecret
        self.daytonaApiKey = daytonaApiKey
        self.daytonaTarget = daytonaTarget
        self.workspaceBase = workspaceBase
        self.cacheDir = cacheDir
        self.workspaceMountPath = workspaceMountPath
        self.workspaceMountPathInSandbox = workspaceMountPathInSandbox
        self.workspaceMountRewrite = workspaceMountRewrite
        self.fileStorePath = fileStorePath
        self.fileStore = fileStore
        self.fileUploadsAllowedExtensions = fileUploadsAllowedExtensions
        self.fileUploadsMaxFileSizeMb = fileUploadsMaxFileSizeMb
        self.fileUploadsRestrictFileTypes = fileUploadsRestrictFileTypes
        self.reasoningEffort = reasoningEffort
        self.debug = debug
        self.disableColor = disableColor
        self.enableCliSession = enableCliSession
        self.saveTrajectoryPath = saveTrajectoryPath
        self.replayTrajectoryPath = replayTrajectoryPath
        self.maxBudgetPerTask = maxBudgetPerTask
        self.maxIterations = maxIterations
        self.runAsOpenhands = runAsOpenhands
        self.runtime = runtime
        self.defaultAgent = defaultAgent
        self.jwtSecret = jwtSecret
        self.enableDefaultCondenser = enableDefaultCondenser
    }
}

/// LLM settings from config.template.toml
public struct LLMSettings: Codable, Equatable {
    // AWS settings
    public var awsAccessKeyId: String?
    public var awsRegionName: String?
    public var awsSecretAccessKey: String?
    
    // API settings
    public var apiKey: String
    public var baseUrl: String?
    public var apiVersion: String?
    
    // Cost settings
    public var inputCostPerToken: Double?
    public var outputCostPerToken: Double?
    
    // Provider settings
    public var customLlmProvider: String?
    
    // Embedding settings
    public var embeddingBaseUrl: String?
    public var embeddingDeploymentName: String?
    public var embeddingModel: String
    
    // Message settings
    public var maxMessageChars: Int?
    public var maxInputTokens: Int?
    public var maxOutputTokens: Int?
    
    // Model settings
    public var model: String
    
    // Retry settings
    public var numRetries: Int?
    public var retryMaxWait: Int?
    public var retryMinWait: Int?
    public var retryMultiplier: Double?
    
    // Parameter settings
    public var dropParams: Bool?
    public var modifyParams: Bool?
    public var cachingPrompt: Bool?
    
    // OLLAMA settings
    public var ollamaBaseUrl: String?
    
    // Generation settings
    public var temperature: Double?
    public var timeout: Int?
    public var topP: Double?
    
    // Vision settings
    public var disableVision: Bool?
    
    // Tokenizer settings
    public var customTokenizer: String?
    
    // Tool calling settings
    public var nativeToolCalling: Bool?
    
    // Additional model configs
    public var additionalModels: [String: LLMModelConfig]?
    
    public init(
        awsAccessKeyId: String? = nil,
        awsRegionName: String? = nil,
        awsSecretAccessKey: String? = nil,
        apiKey: String = "",
        baseUrl: String? = nil,
        apiVersion: String? = nil,
        inputCostPerToken: Double? = nil,
        outputCostPerToken: Double? = nil,
        customLlmProvider: String? = nil,
        embeddingBaseUrl: String? = nil,
        embeddingDeploymentName: String? = nil,
        embeddingModel: String = "local",
        maxMessageChars: Int? = nil,
        maxInputTokens: Int? = nil,
        maxOutputTokens: Int? = nil,
        model: String = "gpt-4o",
        numRetries: Int? = nil,
        retryMaxWait: Int? = nil,
        retryMinWait: Int? = nil,
        retryMultiplier: Double? = nil,
        dropParams: Bool? = nil,
        modifyParams: Bool? = nil,
        cachingPrompt: Bool? = nil,
        ollamaBaseUrl: String? = nil,
        temperature: Double? = nil,
        timeout: Int? = nil,
        topP: Double? = nil,
        disableVision: Bool? = nil,
        customTokenizer: String? = nil,
        nativeToolCalling: Bool? = nil,
        additionalModels: [String: LLMModelConfig]? = nil
    ) {
        self.awsAccessKeyId = awsAccessKeyId
        self.awsRegionName = awsRegionName
        self.awsSecretAccessKey = awsSecretAccessKey
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.apiVersion = apiVersion
        self.inputCostPerToken = inputCostPerToken
        self.outputCostPerToken = outputCostPerToken
        self.customLlmProvider = customLlmProvider
        self.embeddingBaseUrl = embeddingBaseUrl
        self.embeddingDeploymentName = embeddingDeploymentName
        self.embeddingModel = embeddingModel
        self.maxMessageChars = maxMessageChars
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
        self.model = model
        self.numRetries = numRetries
        self.retryMaxWait = retryMaxWait
        self.retryMinWait = retryMinWait
        self.retryMultiplier = retryMultiplier
        self.dropParams = dropParams
        self.modifyParams = modifyParams
        self.cachingPrompt = cachingPrompt
        self.ollamaBaseUrl = ollamaBaseUrl
        self.temperature = temperature
        self.timeout = timeout
        self.topP = topP
        self.disableVision = disableVision
        self.customTokenizer = customTokenizer
        self.nativeToolCalling = nativeToolCalling
        self.additionalModels = additionalModels
    }
}

/// LLM Model Configuration
public struct LLMModelConfig: Codable, Equatable {
    public var apiKey: String?
    public var model: String?
    public var temperature: Double?
    public var maxTokens: Int?
    
    public init(
        apiKey: String? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// Agent settings from config.template.toml
public struct AgentSettings: Codable, Equatable {
    // CodeAct settings
    public var codeactEnableBrowsing: Bool?
    public var codeactEnableLlmEditor: Bool?
    public var codeactEnableJupyter: Bool?
    
    // Agent configuration
    public var microAgentName: String?
    public var memoryEnabled: Bool?
    public var memoryMaxThreads: Int?
    public var llmConfig: String?
    public var enablePromptExtensions: Bool?
    public var disabledMicroagents: [String]?
    public var enableHistoryTruncation: Bool?
    
    // Additional agent configs
    public var additionalAgents: [String: AgentConfig]?
    
    public init(
        codeactEnableBrowsing: Bool? = nil,
        codeactEnableLlmEditor: Bool? = nil,
        codeactEnableJupyter: Bool? = nil,
        microAgentName: String? = nil,
        memoryEnabled: Bool? = nil,
        memoryMaxThreads: Int? = nil,
        llmConfig: String? = nil,
        enablePromptExtensions: Bool? = nil,
        disabledMicroagents: [String]? = nil,
        enableHistoryTruncation: Bool? = nil,
        additionalAgents: [String: AgentConfig]? = nil
    ) {
        self.codeactEnableBrowsing = codeactEnableBrowsing
        self.codeactEnableLlmEditor = codeactEnableLlmEditor
        self.codeactEnableJupyter = codeactEnableJupyter
        self.microAgentName = microAgentName
        self.memoryEnabled = memoryEnabled
        self.memoryMaxThreads = memoryMaxThreads
        self.llmConfig = llmConfig
        self.enablePromptExtensions = enablePromptExtensions
        self.disabledMicroagents = disabledMicroagents
        self.enableHistoryTruncation = enableHistoryTruncation
        self.additionalAgents = additionalAgents
    }
}

/// Agent Configuration
public struct AgentConfig: Codable, Equatable {
    public var llmConfig: String?
    
    public init(llmConfig: String? = nil) {
        self.llmConfig = llmConfig
    }
}

/// Sandbox settings from config.template.toml
public struct SandboxSettings: Codable, Equatable {
    public var timeout: Int?
    public var userId: Int?
    public var baseContainerImage: String?
    public var useHostNetwork: Bool?
    public var runtimeExtraBuildArgs: [String]?
    public var enableAutoLint: Bool?
    public var initializePlugins: Bool?
    public var runtimeExtraDeps: String?
    public var runtimeStartupEnvVars: [String: String]?
    public var browsergymEvalEnv: String?
    
    public init(
        timeout: Int? = nil,
        userId: Int? = nil,
        baseContainerImage: String? = nil,
        useHostNetwork: Bool? = nil,
        runtimeExtraBuildArgs: [String]? = nil,
        enableAutoLint: Bool? = nil,
        initializePlugins: Bool? = nil,
        runtimeExtraDeps: String? = nil,
        runtimeStartupEnvVars: [String: String]? = nil,
        browsergymEvalEnv: String? = nil
    ) {
        self.timeout = timeout
        self.userId = userId
        self.baseContainerImage = baseContainerImage
        self.useHostNetwork = useHostNetwork
        self.runtimeExtraBuildArgs = runtimeExtraBuildArgs
        self.enableAutoLint = enableAutoLint
        self.initializePlugins = initializePlugins
        self.runtimeExtraDeps = runtimeExtraDeps
        self.runtimeStartupEnvVars = runtimeStartupEnvVars
        self.browsergymEvalEnv = browsergymEvalEnv
    }
}

/// Security settings from config.template.toml
public struct SecuritySettings: Codable, Equatable {
    // Security settings
    public var confirmationMode: Bool?
    public var securityAnalyzer: String?
    
    // API security (client-specific)
    public var apiTokens: [String: String]
    
    // Connection security (client-specific)
    public var validateSSLCertificates: Bool
    public var connectionTimeout: TimeInterval
    
    public init(
        confirmationMode: Bool? = nil,
        securityAnalyzer: String? = nil,
        apiTokens: [String: String] = [:],
        validateSSLCertificates: Bool = true,
        connectionTimeout: TimeInterval = 30.0
    ) {
        self.confirmationMode = confirmationMode
        self.securityAnalyzer = securityAnalyzer
        self.apiTokens = apiTokens
        self.validateSSLCertificates = validateSSLCertificates
        self.connectionTimeout = connectionTimeout
    }
}

/// Condenser settings from config.template.toml
public struct CondenserSettings: Codable, Equatable {
    public var type: String
    public var attentionWindow: Int?
    public var keepFirst: Int?
    public var maxEvents: Int?
    public var maxSize: Int?
    public var llmConfig: String?
    
    public init(
        type: String = "noop",
        attentionWindow: Int? = nil,
        keepFirst: Int? = nil,
        maxEvents: Int? = nil,
        maxSize: Int? = nil,
        llmConfig: String? = nil
    ) {
        self.type = type
        self.attentionWindow = attentionWindow
        self.keepFirst = keepFirst
        self.maxEvents = maxEvents
        self.maxSize = maxSize
        self.llmConfig = llmConfig
    }
}