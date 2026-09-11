import Foundation

/// Instance 导出 / 导入 — TODO.md §Instance 导入/导出
///
/// Schema（v1，JSON snake_case）：
/// ```
/// {
///   "schema_version": 1,
///   "kind": "qtunnel.instance.export",
///   "exported_at": "<ISO8601>",
///   "instance": {
///     "server": { "name": "...", "host": "..." },
///     "server_port": 9000,
///     "backend_port": 8080,
///     "crypto_method": "rc4" | "aes256cfb",
///     "password": "<plaintext>"
///   }
/// }
/// ```
/// 注意：不导出 `instance.name`（本机概念，不可移植）。`backend_host` 不参与（固定 127.0.0.1）。
enum InstanceExport {

    static let schemaVersion = 2
    /// v1 没有 `config_name`，导入时回填 `<host>:<serverPort>` 作为 Config 名称
    static let schemaVersionV1 = 1
    static let kind = "qtunnel.instance.export"

    // MARK: - Payload

    struct ServerRef: Codable, Hashable, Sendable {
        let name: String
        let host: String
    }

    struct Instance: Codable, Hashable, Sendable {
        /// v2+；v1 不带此字段，导入时由 `host:serverPort` 推导
        let config_name: String?
        let server: ServerRef
        let server_port: Int
        let backend_port: Int
        let crypto_method: String
        let password: String
    }

    struct Payload: Codable, Hashable, Sendable {
        let schema_version: Int
        let kind: String
        let exported_at: String
        let instance: Instance
    }

    // MARK: - Parsed (decode 后的强类型 + 已校验)

    struct Parsed: Hashable, Sendable {
        let configName: String   // → ClientConfig.name（v2 取自 payload，v1 推导为 `<host>:<serverPort>`）
        let serverRef: ServerRef
        let serverPort: Int      // → ClientConfig.qtunnelPort
        let backendPort: Int     // → ClientConfig.backendPort
        let cryptoMethod: CryptoMethod
        let password: String     // → ClientConfig.secret（明文）
    }

    // MARK: - Errors

    enum ImportError: Error, LocalizedError, Equatable {
        case emptyInput
        case invalidJSON
        case wrongKind
        case unsupportedSchemaVersion(Int)
        case missingField(String)
        case invalidPort(String, Int)
        case invalidCryptoMethod(String)
        case passwordEmpty

        var errorDescription: String? {
            switch self {
            case .emptyInput:               return "Clipboard is empty"
            case .invalidJSON:              return "Invalid JSON"
            case .wrongKind:                return "Not a qtunnel instance export"
            case .unsupportedSchemaVersion(let v): return "Unsupported schema version: \(v)"
            case .missingField(let f):      return "Missing field: \(f)"
            case .invalidPort(let f, let v):return "Invalid port in \(f): \(v)"
            case .invalidCryptoMethod(let v): return "Unknown crypto method: \(v)"
            case .passwordEmpty:            return "Password is empty"
            }
        }
    }

    // MARK: - Encode

    /// 序列化为 JSON 字符串（pretty + sorted keys 便于 diff / 跨工具阅读）
    static func encode(instance: ClientInstance, config: ClientConfig, server: Server) -> String {
        let payload = Payload(
            schema_version: schemaVersion,
            kind: kind,
            exported_at: ISO8601DateFormatter().string(from: Date()),
            instance: Instance(
                config_name: config.name,
                server: ServerRef(name: server.name, host: server.host),
                server_port: config.qtunnelPort,
                backend_port: config.backendPort,
                crypto_method: config.cryptoMethod.cliValue,
                password: config.secret
            )
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        // encode 失败时回退空串（理论上不可能：所有字段都是 Codable + 合法值）
        guard let data = try? enc.encode(payload),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    // MARK: - Decode

    /// 校验 + 解析 JSON 文本 → Parsed
    static func decode(_ json: String) throws -> Parsed {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.emptyInput }
        guard let data = trimmed.data(using: .utf8) else { throw ImportError.invalidJSON }

        // 1. 整体解析
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch is DecodingError {
            throw ImportError.invalidJSON
        } catch {
            throw ImportError.invalidJSON
        }

        // 2. kind
        guard payload.kind == kind else { throw ImportError.wrongKind }

        // 3. schema_version
        guard payload.schema_version == schemaVersion else {
            throw ImportError.unsupportedSchemaVersion(payload.schema_version)
        }

        // 4. 业务字段再校验一遍（防御 CodingKeys 没接住的情况）
        let inst = payload.instance
        guard inst.server.name != "" else { throw ImportError.missingField("instance.server.name") }
        guard inst.server.host != "" else { throw ImportError.missingField("instance.server.host") }
        guard inst.server_port > 0, inst.server_port < 65536 else {
            throw ImportError.invalidPort("server_port", inst.server_port)
        }
        guard inst.backend_port > 0, inst.backend_port < 65536 else {
            throw ImportError.invalidPort("backend_port", inst.backend_port)
        }
        guard let crypto = CryptoMethod.allCases.first(where: { $0.cliValue == inst.crypto_method }) else {
            throw ImportError.invalidCryptoMethod(inst.crypto_method)
        }
        guard !inst.password.isEmpty else { throw ImportError.passwordEmpty }

        // 5. config_name：v1 推导，v2 必填
        let configName: String
        switch payload.schema_version {
        case schemaVersionV1:
            // legacy payload 没有 config_name —— 用 host:port 推导一个与 server.name 区分的名字
            configName = "\(inst.server.host):\(inst.server_port)"
        case schemaVersion:
            guard let name = inst.config_name, !name.isEmpty else {
                throw ImportError.missingField("instance.config_name")
            }
            configName = name
        default:
            throw ImportError.unsupportedSchemaVersion(payload.schema_version)
        }

        return Parsed(
            configName: configName,
            serverRef: inst.server,
            serverPort: inst.server_port,
            backendPort: inst.backend_port,
            cryptoMethod: crypto,
            password: inst.password
        )
    }
}