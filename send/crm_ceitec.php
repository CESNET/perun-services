<?php

require '/etc/perun/services/crm_ceitec/crm_ceitec.php';

$client = new SoapClient("https://wcf3.ceitec.cz/ExternalWWW.WCFService.svc?wsdl", array('login' => $l, 'password' => $p, 'trace' => 'true'));

$longopts  = array(
	"userName:",
	"firstName:",
	"lastName:",
	"email:",
	"orgUnit:",
	"universityId:",
	"eppn:",
	"rgs:",
	"alternativeLoginNames:",
);

$params = getopt("", $longopts);

# public string[] CreateUser ( string userName, string firstName, string lastName, string email, string orgUnit, string universityId, string eppn , string rgs, string alternativeLoginNames )
$response = $client->__soapCall("CreateUser", array($params));

#if ($response->Valid === false) {
#  $msg = "Chyba: " . $response->InvalidParam;
#}

# for debug
#print_r($response);

$array = $response->CreateUserResult->string;

if ($array[0] == 0) {
	print("SUCCESS");
} else {
	print("ERROR: " . $params["userName"] . " " . $array[1]);
}

?>
