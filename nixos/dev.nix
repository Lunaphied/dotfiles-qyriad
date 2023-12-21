# vim: shiftwidth=4 tabstop=4 noexpandtab
{ config, pkgs, qyriad, ... }:

{
	# General development stuffs.

	environment.systemPackages = with pkgs; [
		#llvmPackages_latest.clangUseLLVM
		#llvmPackages_latest.lld
		qyriad.log2compdb
		dprint
		just
		clang-tools_15
		pyright
		nil
		bear
		#rust-analyzer
		#rustfmt
		#cargo
		#rustc
	];
}
