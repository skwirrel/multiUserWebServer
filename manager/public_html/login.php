<?php include('header.php'); ?>
<table width="100%" height="100%"><tr valign="center"><td align="center">
<form method="POST" action="index.php">
<div>
	Password: <input type="password" size="20" name="password" />
	<input type="submit" value="login"/><br />
	<?=htmlspecialchars($error)?>
</div>
</form>
</td></tr></table>
<?php include('footer.php'); ?>
