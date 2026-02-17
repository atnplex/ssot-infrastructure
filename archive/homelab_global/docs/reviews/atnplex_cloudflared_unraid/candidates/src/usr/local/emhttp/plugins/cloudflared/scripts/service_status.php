<?php
// Service status endpoint for Cloudflared plugin
header('Content-Type: application/json');

$response = [
    'running' => false,
    'pid' => null,
    'uptime' => null,
    'token_configured' => false,
    'enabled' => false
];

// Check if cloudflared process is running
$pid = trim(shell_exec('pgrep -x cloudflared'));
if (!empty($pid)) {
    $response['running'] = true;
    $response['pid'] = intval($pid);
    
    // Get process uptime
    $ps_output = shell_exec("ps -p $pid -o etime=");
    if ($ps_output) {
        $response['uptime'] = trim($ps_output);
    }
}

// Check if token is configured
$tokenFile = '/boot/config/plugins/cloudflared/config/token';
if (file_exists($tokenFile) && filesize($tokenFile) > 0) {
    $response['token_configured'] = true;
}

// Check if service is enabled in settings.json
$settingsFile = '/boot/config/plugins/cloudflared/config/settings.json';
if (file_exists($settingsFile)) {
    $settings = json_decode(file_get_contents($settingsFile), true);
    if (isset($settings['current']['enabled'])) {
        $response['enabled'] = (bool)$settings['current']['enabled'];
    }
}

echo json_encode($response);
?>
