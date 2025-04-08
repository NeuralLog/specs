# NeuralLog Unity SDK Specification

## Overview

This specification defines the Unity SDK for NeuralLog, providing game developers with a simple way to integrate advanced logging capabilities into their Unity projects.

## Installation

The SDK is distributed as a Unity package:

1. In Unity, go to Window > Package Manager
2. Click the "+" button and select "Add package from git URL"
3. Enter: `https://github.com/neurallog/unity-sdk.git`

Alternatively, download the .unitypackage file from the releases page and import it into your project.

## Basic Usage

```csharp
using NeuralLog;
using UnityEngine;

public class GameManager : MonoBehaviour
{
    private NeuralLogger _logger;
    
    void Awake()
    {
        // Initialize the logger
        _logger = NeuralLogger.Initialize(new NeuralLogConfig
        {
            ApiKey = "your-api-key",
            Endpoint = "https://api.your-tenant.neurallog.com/v1"
        });
    }
    
    void Start()
    {
        // Log a message
        _logger.Info("Game started", new Dictionary<string, object>
        {
            { "level", "Level 1" },
            { "device", SystemInfo.deviceModel },
            { "platform", Application.platform.ToString() }
        });
    }
    
    public void OnPlayerDeath()
    {
        // Log an error
        _logger.Error("Player died", new Dictionary<string, object>
        {
            { "position", transform.position.ToString() },
            { "health", 0 },
            { "enemies", GameObject.FindGameObjectsWithTag("Enemy").Length }
        });
    }
    
    void OnApplicationQuit()
    {
        // Ensure all logs are sent before quitting
        _logger.Flush();
    }
}
```

## Core Components

### Configuration

```csharp
public class NeuralLogConfig
{
    // Authentication (one of these is required)
    public string ApiKey { get; set; }
    public string Token { get; set; }
    
    // API endpoint (required)
    public string Endpoint { get; set; }
    
    // Optional configuration
    public int Timeout { get; set; } = 30000;
    public int MaxRetries { get; set; } = 3;
    public int BatchSize { get; set; } = 10;
    public int BatchIntervalMs { get; set; } = 5000;
    public bool UseUnityWebRequest { get; set; } = true;
    public LogLevel MinimumLogLevel { get; set; } = LogLevel.Info;
    public bool CaptureUnityLogs { get; set; } = true;
    public bool SendLogsInBackground { get; set; } = true;
    public bool IncludeDeviceInfo { get; set; } = true;
    public bool IncludeSceneInfo { get; set; } = true;
    public bool IncludeStackTrace { get; set; } = true;
}

public enum LogLevel
{
    Debug,
    Info,
    Warn,
    Error,
    Fatal
}
```

### Logger Interface

```csharp
public interface INeuralLogger
{
    // Core logging methods
    Task<LogResult> LogAsync(LogParams logParams);
    Task<BatchLogResult> BatchLogAsync(IEnumerable<LogParams> logs);
    
    // Convenience methods
    Task<LogResult> DebugAsync(string message, Dictionary<string, object> metadata = null);
    Task<LogResult> InfoAsync(string message, Dictionary<string, object> metadata = null);
    Task<LogResult> WarnAsync(string message, Dictionary<string, object> metadata = null);
    Task<LogResult> ErrorAsync(string message, Dictionary<string, object> metadata = null);
    Task<LogResult> FatalAsync(string message, Dictionary<string, object> metadata = null);
    
    // Synchronous versions (internally use async)
    LogResult Log(LogParams logParams);
    LogResult Debug(string message, Dictionary<string, object> metadata = null);
    LogResult Info(string message, Dictionary<string, object> metadata = null);
    LogResult Warn(string message, Dictionary<string, object> metadata = null);
    LogResult Error(string message, Dictionary<string, object> metadata = null);
    LogResult Fatal(string message, Dictionary<string, object> metadata = null);
    
    // Utility methods
    void Flush();
    void SetMinimumLogLevel(LogLevel level);
    void SetApiKey(string apiKey);
    void SetToken(string token);
}
```

## Logging API

### Basic Logging

```csharp
// Log parameters
public class LogParams
{
    public LogLevel Level { get; set; }
    public string Message { get; set; }
    public DateTime? Timestamp { get; set; }
    public string Source { get; set; }
    public Dictionary<string, object> Metadata { get; set; }
    public List<string> Tags { get; set; }
}

// Log result
public class LogResult
{
    public string Id { get; set; }
    public string Timestamp { get; set; }
    public bool Received { get; set; }
    public bool Queued { get; set; }
}

// Usage
await _logger.LogAsync(new LogParams
{
    Level = LogLevel.Error,
    Message = "Failed to load asset",
    Source = "AssetLoader",
    Metadata = new Dictionary<string, object>
    {
        { "assetName", "Player_Model" },
        { "assetPath", "Assets/Models/Player.fbx" }
    },
    Tags = new List<string> { "asset", "loading" }
});

// Convenience methods
await _logger.ErrorAsync("Failed to load asset", new Dictionary<string, object>
{
    { "assetName", "Player_Model" },
    { "assetPath", "Assets/Models/Player.fbx" }
});

// Synchronous version (internally uses async)
_logger.Error("Failed to load asset", new Dictionary<string, object>
{
    { "assetName", "Player_Model" }
});
```

### Batch Logging

```csharp
// Batch log result
public class BatchLogResult
{
    public bool Received { get; set; }
    public int Count { get; set; }
    public List<string> Ids { get; set; }
}

// Usage
var logs = new List<LogParams>
{
    new LogParams
    {
        Level = LogLevel.Info,
        Message = "Level started",
        Metadata = new Dictionary<string, object> { { "level", "Level 1" } }
    },
    new LogParams
    {
        Level = LogLevel.Info,
        Message = "Player spawned",
        Metadata = new Dictionary<string, object> { { "position", "0,0,0" } }
    }
};

await _logger.BatchLogAsync(logs);
```

## Unity Integration

### MonoBehaviour Component

```csharp
// Add this component to a GameObject in your scene
public class NeuralLogBehaviour : MonoBehaviour
{
    [Header("API Configuration")]
    [SerializeField] private string _apiKey;
    [SerializeField] private string _endpoint;
    
    [Header("Logging Configuration")]
    [SerializeField] private LogLevel _minimumLogLevel = LogLevel.Info;
    [SerializeField] private bool _captureUnityLogs = true;
    [SerializeField] private bool _includeDeviceInfo = true;
    [SerializeField] private bool _includeSceneInfo = true;
    
    [Header("Performance")]
    [SerializeField] private int _batchSize = 10;
    [SerializeField] private int _batchIntervalMs = 5000;
    
    private NeuralLogger _logger;
    
    void Awake()
    {
        // Initialize the logger
        _logger = NeuralLogger.Initialize(new NeuralLogConfig
        {
            ApiKey = _apiKey,
            Endpoint = _endpoint,
            MinimumLogLevel = _minimumLogLevel,
            CaptureUnityLogs = _captureUnityLogs,
            IncludeDeviceInfo = _includeDeviceInfo,
            IncludeSceneInfo = _includeSceneInfo,
            BatchSize = _batchSize,
            BatchIntervalMs = _batchIntervalMs
        });
        
        // Don't destroy on scene load
        DontDestroyOnLoad(gameObject);
    }
    
    void OnDestroy()
    {
        // Ensure all logs are sent
        _logger?.Flush();
    }
}
```

### Unity Log Capture

```csharp
// Capture Unity's Debug.Log messages
public class UnityLogCapture
{
    private INeuralLogger _logger;
    
    public UnityLogCapture(INeuralLogger logger)
    {
        _logger = logger;
        Application.logMessageReceived += HandleUnityLog;
    }
    
    public void Dispose()
    {
        Application.logMessageReceived -= HandleUnityLog;
    }
    
    private void HandleUnityLog(string logString, string stackTrace, LogType type)
    {
        var metadata = new Dictionary<string, object>
        {
            { "source", "Unity" },
            { "stackTrace", stackTrace }
        };
        
        switch (type)
        {
            case LogType.Log:
                _logger.Info(logString, metadata);
                break;
            case LogType.Warning:
                _logger.Warn(logString, metadata);
                break;
            case LogType.Error:
            case LogType.Exception:
                _logger.Error(logString, metadata);
                break;
            case LogType.Assert:
                _logger.Fatal(logString, metadata);
                break;
        }
    }
}
```

### Device Information

```csharp
// Collect device information
public static class DeviceInfoCollector
{
    public static Dictionary<string, object> GetDeviceInfo()
    {
        return new Dictionary<string, object>
        {
            { "deviceModel", SystemInfo.deviceModel },
            { "deviceName", SystemInfo.deviceName },
            { "deviceType", SystemInfo.deviceType.ToString() },
            { "operatingSystem", SystemInfo.operatingSystem },
            { "processorType", SystemInfo.processorType },
            { "processorCount", SystemInfo.processorCount },
            { "systemMemorySize", SystemInfo.systemMemorySize },
            { "graphicsDeviceName", SystemInfo.graphicsDeviceName },
            { "graphicsMemorySize", SystemInfo.graphicsMemorySize },
            { "graphicsDeviceVersion", SystemInfo.graphicsDeviceVersion },
            { "screenResolution", $"{Screen.width}x{Screen.height}" },
            { "screenDPI", Screen.dpi },
            { "batteryLevel", SystemInfo.batteryLevel },
            { "batteryStatus", SystemInfo.batteryStatus.ToString() },
            { "platform", Application.platform.ToString() },
            { "unityVersion", Application.unityVersion },
            { "appVersion", Application.version },
            { "productName", Application.productName },
            { "companyName", Application.companyName },
            { "installMode", Application.installMode.ToString() },
            { "internetReachability", Application.internetReachability.ToString() }
        };
    }
}
```

## Error Handling

```csharp
try
{
    await _logger.InfoAsync("Game started");
}
catch (NeuralLogException ex)
{
    Debug.LogError($"NeuralLog error: {ex.Message}");
    
    if (ex is ApiException apiEx)
    {
        Debug.LogError($"API error: {apiEx.StatusCode} - {apiEx.ErrorCode}");
    }
    else if (ex is NetworkException)
    {
        Debug.LogError("Network error - will retry later");
    }
}
```

## Offline Support

```csharp
// The SDK automatically handles offline scenarios
public class OfflineSupport
{
    private readonly Queue<LogParams> _offlineQueue = new Queue<LogParams>();
    private readonly int _maxQueueSize;
    
    public OfflineSupport(int maxQueueSize = 1000)
    {
        _maxQueueSize = maxQueueSize;
        Application.internetReachabilityChanged += HandleConnectivityChange;
    }
    
    public void EnqueueLog(LogParams log)
    {
        if (_offlineQueue.Count >= _maxQueueSize)
        {
            // Remove oldest log if queue is full
            _offlineQueue.Dequeue();
        }
        
        _offlineQueue.Enqueue(log);
    }
    
    private void HandleConnectivityChange(NetworkReachability reachability)
    {
        if (reachability != NetworkReachability.NotReachable)
        {
            // We're back online, send queued logs
            SendQueuedLogs();
        }
    }
    
    private async void SendQueuedLogs()
    {
        // Implementation details
    }
}
```

## WebGL Support

```csharp
// WebGL-specific implementation
#if UNITY_WEBGL
public class WebGLTransport : ITransport
{
    public async Task<Response> SendRequestAsync(Request request)
    {
        // Implementation using UnityWebRequest
    }
}
#endif
```

## Thread Safety

```csharp
// Thread-safe implementation for Unity
public class ThreadSafeLogger
{
    private readonly Queue<LogOperation> _operationQueue = new Queue<LogOperation>();
    private readonly object _queueLock = new object();
    
    public void QueueLogOperation(LogOperation operation)
    {
        lock (_queueLock)
        {
            _operationQueue.Enqueue(operation);
        }
    }
    
    // Process queue on main thread
    public void Update()
    {
        lock (_queueLock)
        {
            while (_operationQueue.Count > 0)
            {
                var operation = _operationQueue.Dequeue();
                ProcessOperation(operation);
            }
        }
    }
    
    private void ProcessOperation(LogOperation operation)
    {
        // Implementation details
    }
}
```

## Implementation Guidelines

1. **Unity Main Thread**: Ensure callbacks run on the main thread
2. **Async Support**: Proper async/await support for Unity
3. **Memory Usage**: Minimize garbage collection
4. **Battery Impact**: Minimize battery usage on mobile
5. **Build Size**: Keep SDK size small
6. **Platform Support**: Support all Unity platforms
7. **Documentation**: Provide comprehensive documentation with examples
