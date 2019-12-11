<?php
$managerPassword = file_get_contents('../managerPassword.txt');
$passwordFile = '../userPasswords.txt';
$passwordResetFile = '../passwordReset.txt';

session_start();

$error = '';
$message = '';
if (isset($_POST['password'])) {
	if (password_verify($_POST['password'],$managerPassword)) $_SESSION['loggedIn']=true;
	else $error='Incorrect Password';
}

if (!isset($_SESSION['loggedIn']) || !$_SESSION['loggedIn']) {
	include('login.php');
	exit;
}

if (isset($_GET['mode'])) {
	if ($_GET['mode']=='logout') {
		session_destroy();
		header('Location: /');
		exit;
	}
	if ($_GET['mode']=='download') {
		header('Content-Type: application/csv');
		header('Content-Disposition: attachment; filename=studentWebsitePasswords.csv');
		header('Pragma: no-cache');
		$lines = file($passwordFile);
		echo "Username,Password\n";
		$out = fopen('php://output', 'w');
		foreach($lines as $line) {
			fputcsv($out,explode(' ',$line,2));
		}
		exit;
	}
	else if ($_GET['mode']=='view') {
		include('header.php');
		echo "<table>";
		echo "<tr><th>Username</th><th>Password</th></tr>";
		$lines = file($passwordFile);
		foreach($lines as $line) {
			list($username,$password)=explode(' ',$line,2);
			printf("<tr><td>%s</td><td>%s</td></tr>",$username,$password);
		}
		echo "</table>";
		echo '<br /><a href="/index.php">Back</a>';
		include('footer.php');
		exit;
	}
}
else if (isset($_POST['mode'])) {
	if ($_POST['mode']=='reset') {
		$user = isset($_POST['username'])?$_POST['username']:'';
		if (!strlen($user)) $error='You must specify a username';
		else {
			$lines = file($passwordFile);
			$found = false;
			foreach($lines as $line) {
				list($username,$password)=explode(' ',$line,2);
				if ($username===$user) {
					$found=true;
					break;
				}
			}
			if (!$found) $error='No such user';
			else {
				$message = 'Password reset triggered for User: '.$user.'. They will recieve an email with their new password - this may take up to 5 minutes to arrive';
				file_put_contents($passwordResetFile,$user."\n",FILE_APPEND);
			}
		}
	}
}

include('header.php');
?>
<?php if ($message) {
	echo '<div class="message">'.htmlspecialchars($message).'</div><br />';
} ?>
<a href="index.php?mode=download"><button>Download Password File</button></a>
<a href="index.php?mode=view"><button>View Password File</button></a>
<br /><br />
<form action="index.php" method="post">
<input type="hidden" name="mode" value="reset" />
Reset password for user: <input type="textbox" name="username" size="20" /><input type="submit" value="Go!" /><br />
<?php if ($error) echo '<div class="error">'.htmlspecialchars($error).'</div>'; ?>
</form>
<br />
<a href="index.php?mode=logout"><button>Logout</button></a>

<?php include('footer.php'); ?>
