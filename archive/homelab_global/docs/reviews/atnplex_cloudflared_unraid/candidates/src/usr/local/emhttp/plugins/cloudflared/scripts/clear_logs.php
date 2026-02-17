<?php
// Clear logs endpoint for Cloudflared plugin
header('Content-Type: application/json');

$response = ['success' => false, 'message' => ''];
$logFile = '/var/log/cloudflared/cloudflared.log';

if (file_exists($logFile)) {
    // Clear the log file
    if (file_put_contents($logFile, '') !== false) {
        $response['success'] = true;
        $response['message'] = 'Logs cleared successfully';
    } else {
        $response['message'] = 'Failed to clear logs - permission denied';
    }
} else {
    $response['success'] = true;
    $response['message'] = 'Log file does not exist';
}

echo json_encode($response);
?>
