compile:
	@aptos move compile --named-addresses admin_addr=0x11,mint_nft=0xff1b107b910ba8ee1317d238e543ecba99e2435a5a35ff900f3c5f10d507db16,source_addr=0xff1b107b910ba8ee1317d238e543ecba99e2435a5a35ff900f3c5f10d507db16,resource_account=0xff1b107b910ba8ee1317d238e543ecba99e2435a5a35ff900f3c5f10d507db16

test:
	@aptos move test --named-addresses admin_addr=0xcafe,mint_nft=0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,source_addr=0xcafe,resource_account=0xff1b107b910ba8ee1317d238e543ecba99e2435a5a35ff900f3c5f10d507db16 --dump

create_resource_account:
	@aptos move create-resource-account-and-publish-package --seed hex_array:1234 --address-name mint_nft --profile account1 --named-addresses source_addr=ff1b107b910ba8ee1317d238e543ecba99e2435a5a35ff900f3c5f10d507db16 

start_node:
	@aptos node run-local-testnet --with-faucet

create_profile_account1:
	@aptos init --profile account1

create_profile_account2:
	@aptos init --profile account2

upgrade_aptos_cli:
	@brew upgrade aptos
