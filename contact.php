<?php
# =============================================================================
# contact.php
#
# PURPOSE: Secure contact form handler for VisDir
#          Honeypot anti-spam + proper email headers
# AUTHOR: Generated for the visdir project
# VERSION: 1.0.0
# =============================================================================

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    header("Location: contact.html");
    exit;
}

# Honeypot anti-spam check
if (!empty($_POST['honeypot'])) {
    header("Location: contact.html?status=success");
    exit;
}

# Sanitize input
$name    = strip_tags(trim($_POST['name'] ?? ''));
$email   = filter_var(trim($_POST['email'] ?? ''), FILTER_SANITIZE_EMAIL);
$message = strip_tags(trim($_POST['message'] ?? ''));

if (empty($name) || empty($email) || empty($message) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    header("Location: contact.html?status=error");
    exit;
}

# CHANGE THIS TO YOUR EMAIL
$to = "you@example.com";

$subject = "VisDir Contact Form – " . $name;

$body = "Name: " . $name . "\n";
$body .= "Email: " . $email . "\n\n";
$body .= "Message:\n" . $message . "\n\n";
$body .= "---\nSent via VisDir contact form";

$headers = "From: no-reply@yourdomain.com\r\n";
$headers .= "Reply-To: " . $email . "\r\n";
$headers .= "X-Mailer: PHP/" . phpversion();

if (mail($to, $subject, $body, $headers)) {
    header("Location: contact.html?status=success");
} else {
    header("Location: contact.html?status=error");
}

exit;
?>
