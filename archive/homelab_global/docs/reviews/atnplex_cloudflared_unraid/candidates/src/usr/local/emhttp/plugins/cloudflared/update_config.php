<?php
// Configuration update endpoint for Cloudflared plugin

$configDir = '/boot/config/plugins/cloudflared/config';
$tokenFile = "$configDir/token";
$settingsFile = "$configDir/settings.json";

// Ensure config directory exists
if (!is_dir($configDir)) {
    mkdir($configDir, 0700, true);
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $updated = false;
    
    // Handle tunnel token update
    $tunnelToken = trim($_POST['tunnel_token'] ?? '');
    if (!empty($tunnelToken)) {
        // Validate token format (should start with eyJ for JWT tokens)
        if (strpos($tunnelToken, 'eyJ') === 0) {
            // Save the token
            file_put_contents($tokenFile, $tunnelToken);
            chmod($tokenFile, 0600);
            $updated = true;
        } else {
            // Invalid token format - redirect with error
            header('Location: /Settings/Cloudflared?error=invalid_token');
            exit;
        }
    }
    
    // Handle service enabled checkbox
    $serviceEnabled = isset($_POST['service_enabled']) && $_POST['service_enabled'] == '1';
    
    // Load current settings
    $settings = [];
    if (file_exists($settingsFile)) {
        $settingsJson = file_get_contents($settingsFile);
        $settings = json_decode($settingsJson, true);
        
        // Handle JSON decode failure
        if ($settings === null && json_last_error() !== JSON_ERROR_NONE) {
            error_log("Failed to decode settings.json: " . json_last_error_msg() . ", creating new settings");
            $settings = [];
        }
    }
    
    // Initialize settings structure if needed
    if (!isset($settings['meta'])) {
        $settings['meta'] = ['schema' => 1, 'history_limit' => 5];
    }
    if (!isset($settings['current'])) {
        $settings['current'] = [
            'enabled' => false,
            'logging_mode' => 'disabled',
            'log_level' => 'info',
            'log_persist_path' => '',
            'logrotate' => ['enabled' => false, 'max_size_mb' => 5, 'keep' => 3]
        ];
    }
    if (!isset($settings['history'])) {
        $settings['history'] = [];
    }
    
    // Update enabled setting
    $settings['current']['enabled'] = $serviceEnabled;
    
    // Save settings
    file_put_contents($settingsFile, json_encode($settings, JSON_PRETTY_PRINT));
    chmod($settingsFile, 0600);
    $updated = true;
    
    if ($updated) {
        // Redirect back to settings page with success message
        header('Location: /Settings/Cloudflared?success=1');
        exit;
    }
}

// Redirect back if accessed directly
header('Location: /Settings/Cloudflared');
exit;
?>
