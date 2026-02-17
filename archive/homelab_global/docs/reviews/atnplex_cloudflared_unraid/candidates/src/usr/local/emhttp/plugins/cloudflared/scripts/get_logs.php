<?php
// Get logs endpoint for Cloudflared plugin
header('Content-Type: text/plain');

$logFile = '/var/log/cloudflared/cloudflared.log';
$maxLines = 500; // Last 500 lines

if (file_exists($logFile)) {
    // Get last N lines efficiently
    $output = shell_exec("tail -n $maxLines " . escapeshellarg($logFile));
    echo $output ?: 'Log file is empty';
} else {
    echo 'No logs available - log file not found';
}
?>
