<?php
session_start ();
include_once ('../config/config.inc.php');
include_once ($conf['lib'] . '/functions.php');
include_once ($conf['lib'] . '/DB.class.php');
include_once ($conf['lib'] . '/package.class.php');
include_once ($conf['lib'] . '/user.class.php');
include_once ($conf['lib'] . '/pureftpd.class.php');

$db = new DB($conf['db_dsn'], $conf['db_user'], $conf['db_passwd']);


connect ();

$template = 'pkg_search.php';
if (isset ($_GET['action']))
{
	switch ($_GET['action'])
	{
		case 'disconnect':
			disconnect ();
			redirect ('search');
			break;
		case 'connect':
			if (connect ())
				redirect ('search');
			else
				$template = 'user_connect.php';
			break;
		case 'search':
			if (!isset ($_GET['q'])) break;
			$packages = pkg_search ($db, array ('name' => $_GET['q']), $_GET['sort']);
			$template = 'pkg_search.php';
			break;
		case 'list':
			if (!isset ($_GET['u'])) break;
			$packages = pkg_search ($db, array ('user_id' => $_GET['u']));
			$template = 'pkg_search.php';
			break;
		case 'view':
			if (isset ($_GET['p']))
			{
				$pkg = new Package ($db, $_GET['p']);
				$template = 'pkg_view.php';
			}
			elseif (isset ($_GET['u']))
			{
				$user = new User ($db, $_GET['u']);
				$template = 'user_view.php';
			}
			break;
		case 'profile':
			if ($is_connected)
			{
				if ($is_admin and isset ($_GET['user_id']))
					$user = new User ($db, $_GET['user_id']);
				else
					$user = new User ($db, $user_id);
				$template = 'user_profile.php';
			}
			break;
		case 'update':
			if ($is_connected)
			{
				if (!$_POST['user_id'] and (!$is_admin 
				  or !$_POST['passwd']))
					break;
				if (!$_POST['user_id'])
					$user = new User ($db, $_POST['user_id']);
				else
					$user = new User ($db);
				if ($_POST['passwd'] == $_POST['passwd_verif'])
				{
					if ($is_admin)
						$user->set_nick ($_POST['nick']);
					$user->set_mail ($_POST['mail']);
					$user->set_name ($_POST['name']);
					if (isset ($_POST['announce']))
					$user->set_announce ($_POST['announce']);
					if ($is_admin and isset ($_POST['admin']))
						$user->set_admin ($_POST['admin']);
					if (!$_POST['user_id'])
						$ret = $user->insert ();
					else
						$ret = $user->update ();
					if ($ret)
						if ($_POST['passwd'] != '')
							$user->set_passwd ($_POST['passwd']);
				}
				$template = 'user_profile.php';
			}
			break;
		case 'create':
			if (!$is_admin) break;
			$user = new User ($db);
			$template = 'user_profile.php';
			break;
		case 'outofdate':
			if (!isset ($_GET['p'])) break;
			$pkg = new Package ($db, $_GET['p']);
			if ($pkg->get('outofdate') and 
			  (!$is_connected or ($user_id != $pkg->get('user_id') and !$is_admin)))
				break;
			$pkg->set_outofdate ();
			redirect ('view', array ('p' => $_GET['p']));
			break;
		case 'adopt':
			if (!isset ($_GET['p']) or !$is_connected) break;
			$pkg = new Package ($db, $_GET['p']);
			$pkg->adopt ($user_id);
			redirect ('view', array ('p' => $_GET['p']));
			break;
		case 'disown':
			if (!isset ($_GET['p']) or !$is_connected) break;
			$pkg = new Package ($db, $_GET['p']);
			if ($pkg->get('user_id') == $user_id)
				$pkg->disown ();
			redirect ('view', array ('p' => $_GET['p']));
			break;
		case 'remove':
			if (!isset ($_GET['p']) or !$is_admin) break;
			$pkg = new Package ($db, $_GET['p']);
			$pkg->remove ();
			redirect ('search');
			break;
		case 'generate':
			if (!$is_connected) break;
			$user = new User ($db, $user_id);
			$dbf = new DB($conf['pureftpd_db_dsn'], $conf['pureftpd_db_user'], $conf['pureftpd_db_passwd']);
			$ftp = new Pureftpd ($dbf);
			$str = $ftp->generate ($user->get ('nick'));
			if (!$str) break;
			$template = 'ftp_access.php';
			break;

	}
}

include ($conf['templates'] . '/' . $template);
?>