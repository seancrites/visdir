<?php

/**
 * visdir Contact Form Handler
 *
 * @package     visdir
 * @version     1.5.0
 * @author      Sean Crites
 * @license     GPL-3.0
 * @link        https://github.com/seancrites/visdir
 *
 * Secure contact form with layered anti-spam protection
 * (CSS honeypot + time gate + origin validation) plus optional
 * CAPTCHA support (Cloudflare Turnstile, reCAPTCHA v3, hCaptcha).
 */

// Reject non-POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST')
{
   header('Location: contact.html');
   exit;
}

// ==========================================================================
// ANTI-SPAM PROTECTIONS
// ==========================================================================

// 1. HONEYPOT CHECK
// Bots automatically fill every field. Humans will never see this field.
// If anything is present here: it is 100% a bot.
if (!empty($_POST['website']))
{
   header('Location: contact.html?status=success');
   exit;
}

// 2. MINIMUM SUBMISSION DELAY (TIME GATE)
// Adjust this value if needed:
// 3 = minimum 3 seconds (recommended, stops 95% of bots)
// 5 = minimum 5 seconds (very aggressive)
// 0 = disable this check
$MINIMUM_SUBMIT_SECONDS = 3;
$current_time   = time();
$form_load_time = (int)($_POST['ts'] ?? 0);
$time_diff      = $current_time - $form_load_time;

// Reject submissions faster than minimum delay
if ($MINIMUM_SUBMIT_SECONDS > 0 && $time_diff < $MINIMUM_SUBMIT_SECONDS)
{
   header('Location: contact.html?status=success');
   exit;
}

// 3. ORIGIN / REFERER VALIDATION
// Only accept submissions coming from this actual contact page
$valid_referer = false;
if (isset($_SERVER['HTTP_REFERER']))
{
   $referer_host = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST);
   $server_host  = $_SERVER['HTTP_HOST'];
   if ($referer_host === $server_host)
   {
      $valid_referer = true;
   }
}

// Enforce referer check:
$ENFORCE_REFERER_CHECK = false;
if ($ENFORCE_REFERER_CHECK && !$valid_referer)
{
   header('Location: contact.html?status=success');
   exit;
}

// ==========================================================================
// INPUT VALIDATION & SANITIZATION
// ==========================================================================

$name    = strip_tags(trim($_POST['name'] ?? ''));
$email   = filter_var(trim($_POST['email'] ?? ''), FILTER_SANITIZE_EMAIL);
$message = strip_tags(trim($_POST['message'] ?? ''));

if (empty($name) || empty($email) || empty($message) || !filter_var($email, FILTER_VALIDATE_EMAIL))
{
   header('Location: contact.html?status=error');
   exit;
}

// ==========================================================================
// CAPTCHA VALIDATION (OPTIONAL)
// ==========================================================================

// --- Cloudflare Turnstile (Recommended) ---
/* TURNSTILE-BEGIN
$turnstile_token = $_POST['cf-turnstile-response'] ?? '';
if (empty($turnstile_token)) {
   header('Location: contact.html?status=error');
   exit;
}
$secret   = 'TURNSTILE_SECRET_KEY';
$response = file_get_contents('https://challenges.cloudflare.com/turnstile/v0/siteverify', false, stream_context_create([
   'http' => [
      'method'  => 'POST',
      'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
      'content' => http_build_query(['secret' => $secret, 'response' => $turnstile_token])
   ]
]));
$resp = json_decode($response);
if (!$resp || !$resp->success) {
   header('Location: contact.html?status=error');
   exit;
}
TURNSTILE-END */

// --- Google reCAPTCHA v3 ---
/* RECAPTCHA-BEGIN
$recaptcha_token = $_POST['recaptcha_token'] ?? '';
if (empty($recaptcha_token)) {
    header('Location: contact.html?status=error');
    exit;
}
$secret = 'RECAPTCHA_SECRET_KEY';
$resp   = file_get_contents("https://www.google.com/recaptcha/api/siteverify?secret={$secret}&response={$recaptcha_token}");
$resp   = json_decode($resp);
if (!$resp || $resp->score < 0.5) {
    header('Location: contact.html?status=error');
    exit;
}
RECAPTCHA-END */

// --- hCaptcha ---
/* HCAPTCHA-BEGIN
$hcaptcha_token = $_POST['h-captcha-response'] ?? '';
if (empty($hcaptcha_token)) {
    header('Location: contact.html?status=error');
    exit;
}
$secret   = 'HCAPTCHA_SECRET_KEY';
$response = file_get_contents('https://hcaptcha.com/siteverify', false, stream_context_create([
    'http' => [
        'method'  => 'POST',
        'header'  => "Content-type: application/x-www-form-urlencoded\r\n",
        'content' => http_build_query(['secret' => $secret, 'response' => $hcaptcha_token])
    ]
]));
$resp = json_decode($response);
if (!$resp || !$resp->success) {
    header('Location: contact.html?status=error');
    exit;
}
HCAPTCHA-END */

// ==========================================================================
// EMAIL HANDLING
// ==========================================================================

// CHANGE THIS TO YOUR EMAIL
$to      = 'you@example.com';
$subject = 'VisDir Contact Form – ' . $name;

$body  = "Name: {$name}\n";
$body .= "Email: {$email}\n\n";
$body .= "Message:\n{$message}\n\n";
$body .= "---\nSent via VisDir contact form";

$headers  = "From: no-reply@yourdomain.com\r\n";
$headers .= "Reply-To: {$email}\r\n";
$headers .= 'X-Mailer: PHP/' . phpversion();

if (mail($to, $subject, $body, $headers))
{
   header('Location: contact.html?status=success');
}
else
{
   header('Location: contact.html?status=error');
}

exit;
