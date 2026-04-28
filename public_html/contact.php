<?php
# =============================================================================
# contact.php
#
# PURPOSE: Secure contact form handler for VisDir
#          Layered anti-spam protections + proper email headers
# AUTHOR: Generated for the visdir project
# VERSION: 1.1.0
# =============================================================================

if ($_SERVER["REQUEST_METHOD"] !== "POST")
{
   header("Location: contact.html");
   exit;
}

# =============================================================================
#                           ANTI-SPAM PROTECTIONS
# =============================================================================

# --------------------------
# 1. HONEYPOT CHECK
# Bots automatically fill every field. Humans will never see this field.
# If anything is present here: it is 100% a bot.
if (!empty($_POST['website']))
{
   header("Location: contact.html?status=success");
   exit;
}

# --------------------------
# 2. MINIMUM SUBMISSION DELAY (TIME GATE)
# Adjust this value if needed:
# 3  = minimum 3 seconds (recommended, stops 95% of bots)
# 5  = minimum 5 seconds (very aggressive)
# 0  = disable this check
$MINIMUM_SUBMIT_SECONDS = 3;

$current_time = time();
$form_load_time = (int)$_POST['ts'];
$time_diff = $current_time - $form_load_time;

# Reject submissions faster than minimum delay
if ($MINIMUM_SUBMIT_SECONDS > 0 && $time_diff < $MINIMUM_SUBMIT_SECONDS)
{
   header("Location: contact.html?status=success");
   exit;
}

# --------------------------
# 3. ORIGIN / REFERER VALIDATION
# Only accept submissions coming from this actual contact page
$valid_referer = false;
if (isset($_SERVER['HTTP_REFERER']))
{
   $referer_host = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST);
   $server_host = $_SERVER['HTTP_HOST'];

   if ($referer_host === $server_host)
   {
      $valid_referer = true;
   }
}

# Uncomment below line to enforce referer check:
# if (!$valid_referer) { header("Location: contact.html?status=success"); exit; }

# =============================================================================
#                        INPUT VALIDATION & SANITIZATION
# =============================================================================

# Sanitize input
$name    = strip_tags(trim($_POST['name'] ?? ''));
$email   = filter_var(trim($_POST['email'] ?? ''), FILTER_SANITIZE_EMAIL);
$message = strip_tags(trim($_POST['message'] ?? ''));

if (empty($name) || empty($email) || empty($message) || !filter_var($email, FILTER_VALIDATE_EMAIL))
{
   header("Location: contact.html?status=error");
   exit;
}

# =============================================================================
#                              EMAIL HANDLING
# =============================================================================

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

if (mail($to, $subject, $body, $headers))
{
   header("Location: contact.html?status=success");
}
else
{
   header("Location: contact.html?status=error");
}

exit;
