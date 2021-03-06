<?php

include_once ('DB.class.php');

function mkpasswd ($len)
{
    $chars = "abcdefghijkmnopqrstuvwxyz023456789";
    srand((double)microtime()*1000000);
    $i = 0;
    $pass = '' ;

    while ($i <= $len) 
	{
        $num = rand() % strlen($chars);
        $pass = $pass . $chars[$num];
        $i++;
    }
    return $pass;
}

class Pureftpd
{
	private $db;
	
	public function __construct (&$db)
	{
		$this->db =& $db;
	}
	
	public function generate($user)
	{
		if (!preg_match ('/^[a-zA-Z0-9]+$/', $user))
			return false;
		$folder = $GLOBALS['conf']['pureftpd_dir'] . '/' . $user;
		if (!file_exists ($folder))
		{
			$old_umask = umask (0);
			if (!@mkdir ($folder, 0775))
			{
				umask ($old_umask);
				return false;
			}
			umask ($old_umask);
		}
		$param = array ($user);
		if ($this->db->execute ($GLOBALS['conf']['pureftpd_db_delete'], 
		  $param)===false)
			return false;
		$passwd = mkpasswd (8);
		$param = array ($user, md5($passwd),
		  $GLOBALS['conf']['pureftpd_uid'],
		  $GLOBALS['conf']['pureftpd_gid'], 
		  $GLOBALS['conf']['pureftpd_dir'] . '/' . $user);
		if ($this->db->execute ($GLOBALS['conf']['pureftpd_db_insert'], 
		  $param)===false)
			return false;
		$str = 'SRV_URI="' . $GLOBALS['conf']['pureftpd_uri'] . '"' . "\n";
		$str .= 'USER="' . $user . '"' . "\n";
		$str .= 'PASSWD="' . $passwd . '"' . "\n";
		return $str;
	}
	

};

?>
