//
//  MBRobotsRunner.swift
//  Micro.blog
//

import Foundation
import MLX
import MLXLMCommon
import MLXVLM
import Tokenizers

@objc(MBRobotsPromptRunner)
class MBRobotsPromptRunner: NSObject {
	private static let engine = MBRobotsPromptEngine()

	@objc class func preloadModel(modelFolderPath: String, completion: @escaping (Bool) -> Void) {
		Task.detached(priority: .utility) {
			let success: Bool
			do {
				try await engine.preloadModel(modelFolderPath: modelFolderPath)
				success = true
			}
			catch {
				NSLog("Local AI model preload failed: \(error.localizedDescription)")
				success = false
			}

			DispatchQueue.main.async {
				completion(success)
			}
		}
	}

	@objc class func unloadModel(completion: @escaping () -> Void) {
		Task.detached(priority: .utility) {
			await engine.unloadModel()

			DispatchQueue.main.async {
				completion()
			}
		}
	}

	@objc class func runPrompt(_ prompt: String, modelFolderPath: String) -> String {
		let semaphore = DispatchSemaphore(value: 0)
		let lock = NSLock()
		var output = ""

		Task.detached(priority: .userInitiated) {
			let result: String
			do {
				result = try await engine.runPrompt(prompt, modelFolderPath: modelFolderPath)
			}
			catch {
				NSLog("Local AI prompt failed: \(error.localizedDescription)")
				result = ""
			}

			lock.withLock {
				output = result
			}
			semaphore.signal()
		}

		semaphore.wait()
		return lock.withLock {
			output
		}
	}

	@objc class func runPrompt(_ prompt: String, modelFolderPath: String, completion: @escaping (String) -> Void) {
		Task.detached(priority: .utility) {
			let result: String
			do {
				result = try await engine.runPrompt(prompt, modelFolderPath: modelFolderPath)
			}
			catch {
				NSLog("Local AI prompt failed: \(error.localizedDescription)")
				result = ""
			}

			DispatchQueue.main.async {
				completion(result)
			}
		}
	}

	@objc class func runPrompt(_ prompt: String, imageFilePath: String, modelFolderPath: String, completion: @escaping (String) -> Void) {
		Task.detached(priority: .utility) {
			let result: String
			do {
				result = try await engine.runPrompt(prompt, imageFilePath: imageFilePath, modelFolderPath: modelFolderPath)
			}
			catch {
				NSLog("Local AI image prompt failed: \(error.localizedDescription)")
				result = ""
			}

			DispatchQueue.main.async {
				completion(result)
			}
		}
	}
}

private actor MBRobotsPromptEngine {
	private var modelContainer: ModelContainer?
	private var modelFolderPath: String?

	func runPrompt(_ prompt: String, modelFolderPath: String) async throws -> String {
		let model = try await loadModelIfNeeded(modelFolderPath: modelFolderPath)
		let session = ChatSession(
			model,
			instructions: "You are a helpful assistant.",
			generateParameters: GenerateParameters(maxTokens: 1024, temperature: 0.6)
		)
		let response = try await session.respond(to: prompt)
		return MBRobotsPromptCleaner.clean(response)
	}

	func runPrompt(_ prompt: String, imageFilePath: String, modelFolderPath: String) async throws -> String {
		let model = try await loadModelIfNeeded(modelFolderPath: modelFolderPath)
		let session = ChatSession(
			model,
			instructions: "You are a helpful assistant.",
			generateParameters: GenerateParameters(maxTokens: 1024, temperature: 0.6)
		)
		let imageURL = URL(fileURLWithPath: imageFilePath)
		let response = try await session.respond(to: prompt, image: .url(imageURL))
		return MBRobotsPromptCleaner.clean(response)
	}

	func preloadModel(modelFolderPath: String) async throws {
		_ = try await loadModelIfNeeded(modelFolderPath: modelFolderPath)
	}

	func unloadModel() {
		let hadModel = modelContainer != nil
		modelContainer = nil
		modelFolderPath = nil
		if hadModel {
			Memory.clearCache()
		}
	}

	private func loadModelIfNeeded(modelFolderPath: String) async throws -> ModelContainer {
		if let modelContainer, self.modelFolderPath == modelFolderPath {
			return modelContainer
		}

		Memory.cacheLimit = 20 * 1024 * 1024
		let modelURL = URL(fileURLWithPath: modelFolderPath, isDirectory: true)
		let modelContainer = try await MBRobotsGemma4Loader.loadModelContainer(from: modelURL)
		self.modelContainer = modelContainer
		self.modelFolderPath = modelFolderPath
		return modelContainer
	}
}

private enum MBRobotsGemma4Loader {
	static func loadModelContainer(from modelURL: URL) async throws -> ModelContainer {
		let configURL = modelURL.appendingPathComponent("config.json")
		let configData = try Data(contentsOf: configURL)
		let baseConfig = try JSONDecoder.json5().decode(BaseConfiguration.self, from: configData)
		let modelConfig = try JSONDecoder.json5().decode(Gemma4Configuration.self, from: configData)
		let model = Gemma4(modelConfig)

		try loadWeights(
			modelDirectory: modelURL,
			model: model,
			perLayerQuantization: baseConfig.perLayerQuantization
		)

		let tokenizer = try await MBRobotsTokenizerLoader().load(from: modelURL)
		let processor = try makeProcessor(tokenizer: tokenizer)
		let configuration = ModelConfiguration(
			directory: modelURL,
			extraEOSTokens: ["<end_of_turn>"],
			eosTokenIds: eosTokenIds(from: modelURL, baseConfig: baseConfig),
			toolCallFormat: ToolCallFormat.infer(from: baseConfig.modelType, configData: configData)
		)
		let context = ModelContext(
			configuration: configuration,
			model: model,
			processor: processor,
			tokenizer: tokenizer
		)
		return ModelContainer(context: context)
	}

	private static func makeProcessor(tokenizer: any MLXLMCommon.Tokenizer) throws -> Gemma4Processor {
		let data = Data(#"{"processor_class":"Gemma4Processor"}"#.utf8)
		let config = try JSONDecoder.json5().decode(Gemma4ProcessorConfiguration.self, from: data)
		return Gemma4Processor(config, tokenizer: tokenizer)
	}

	private static func eosTokenIds(from modelURL: URL, baseConfig: BaseConfiguration) -> Set<Int> {
		let generationConfigURL = modelURL.appendingPathComponent("generation_config.json")
		if let generationData = try? Data(contentsOf: generationConfigURL),
			let generationConfig = try? JSONDecoder.json5().decode(GenerationConfigFile.self, from: generationData),
			let genEosIds = generationConfig.eosTokenIds?.values {
			return Set(genEosIds)
		}

		return Set(baseConfig.eosTokenIds?.values ?? [])
	}
}

private enum MBRobotsPromptCleaner {
	static func clean(_ response: String) -> String {
		var s = response
		s = removeChannelBlocks(from: s)
		s = removeControlTokens(from: s)
		return s.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private static func removeChannelBlocks(from response: String) -> String {
		var s = response
		let pattern = #"<\|channel\>[^<\n]*\n([\s\S]*?)<channel\|>"#
		while let range = s.range(of: pattern, options: .regularExpression) {
			s.removeSubrange(range)
		}

		return s
	}

	private static func removeControlTokens(from response: String) -> String {
		let tokens = [
			"<|turn>",
			"<turn|>",
			"<|channel>",
			"<channel|>",
			"<|tool_call>",
			"<tool_call|>",
			"<|tool_response>",
			"<tool_response|>",
			"<|think|>"
		]

		return tokens.reduce(response) { partial, token in
			partial.replacingOccurrences(of: token, with: "")
		}
	}
}

private struct MBRobotsTokenizerLoader: TokenizerLoader {
	func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
		let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
		return MBRobotsTokenizer(upstream)
	}
}

private struct MBRobotsTokenizer: MLXLMCommon.Tokenizer {
	private let upstream: any Tokenizers.Tokenizer

	init(_ upstream: any Tokenizers.Tokenizer) {
		self.upstream = upstream
	}

	func encode(text: String, addSpecialTokens: Bool) -> [Int] {
		upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
	}

	func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
		upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
	}

	func convertTokenToId(_ token: String) -> Int? {
		upstream.convertTokenToId(token)
	}

	func convertIdToToken(_ id: Int) -> String? {
		upstream.convertIdToToken(id)
	}

	var bosToken: String? { upstream.bosToken }
	var eosToken: String? { upstream.eosToken }
	var unknownToken: String? { upstream.unknownToken }

	func applyChatTemplate(
		messages: [[String: any Sendable]],
		tools: [[String: any Sendable]]?,
		additionalContext: [String: any Sendable]?
	) throws -> [Int] {
		do {
			return try upstream.applyChatTemplate(
				messages: messages,
				tools: tools,
				additionalContext: additionalContext
			)
		}
		catch Tokenizers.TokenizerError.missingChatTemplate {
			return gemma4ChatTemplateTokens(messages: messages)
		}
	}

	private func gemma4ChatTemplateTokens(messages: [[String: any Sendable]]) -> [Int] {
		var prompt = bosToken ?? ""

		for message in messages {
			let messageRole = message["role"] as? String ?? "user"
			let role = messageRole == "assistant" ? "model" : messageRole
			prompt += "<|turn>\(role)\n"
			prompt += gemma4ContentText(message["content"])
			prompt += "<turn|>\n"
		}

		prompt += "<|turn>model\n"
		return encode(text: prompt, addSpecialTokens: false)
	}

	private func gemma4ContentText(_ content: (any Sendable)?) -> String {
		if let text = content as? String {
			return text.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		if let parts = content as? [[String: String]] {
			return parts.compactMap { part in
				switch part["type"] {
				case "text":
					return part["text"]?.trimmingCharacters(in: .whitespacesAndNewlines)
				case "image":
					return "<|image|>"
				case "audio":
					return "<|audio|>"
				case "video":
					return "<|video|>"
				default:
					return nil
				}
			}.joined()
		}

		return ""
	}
}
