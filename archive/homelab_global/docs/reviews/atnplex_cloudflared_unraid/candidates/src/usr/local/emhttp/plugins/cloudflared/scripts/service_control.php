<?php
// Service control endpoint for Cloudflared plugin
header('Content-Type: application/json');

$action = $_POST['action'] ?? '';
$response = ['success' => false, 'message' => ''];

if (empty($action)) {
    $response['message'] = 'No action specified';
    echo json_encode($response);
    exit;
}

// Path to the cloudflaredctl script
$ctlScript = '/usr/local/emhttp/plugins/cloudflared/scripts/cloudflaredctl';

if (!file_exists($ctlScript)) {
    $response['message'] = 'Control script not found';
    echo json_encode($response);
    exit;
}

// Execute the control script
switch ($action) {
    case 'start':
        $output = shell_exec("$ctlScript start 2>&1");
        $response['success'] = true;
        $response['message'] = 'Service start command executed';
        break;
    
    case 'stop':
        $output = shell_exec("$ctlScript stop 2>&1");
        $response['success'] = true;
        $response['message'] = 'Service stop command executed';
        break;
    
    case 'restart':
        $output = shell_exec("$ctlScript restart 2>&1");
        $response['success'] = true;
        $response['message'] = 'Service restart command executed';
        break;
    
    default:
        $response['message'] = 'Invalid action specified';
        break;
}

echo json_encode($response);
?>
