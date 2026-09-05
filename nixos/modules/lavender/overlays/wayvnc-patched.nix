final: prev: {
  # Adds rate-control / low-power knobs to neatvnc's VAAPI encoder, driven by env vars
  # set in modules/wayvnc.nix. neatvnc already sets max_b_frames=0 and async_depth=1.
  # substituteInPlace aborts the build if upstream changes these lines, so drift is loud.
  neatvnc = prev.neatvnc.overrideAttrs (old: {
    # QEMU Pointer Motion Change + a private toggle so the client can switch to relative deltas.
    patches = (old.patches or [ ]) ++ [ ../patches/neatvnc-relative-pointer.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/enc/h264/ffmpeg-impl.c \
        --replace-fail 'av_dict_set_int(&opts, "async_depth", 1, 0);' \
        'av_dict_set_int(&opts, "async_depth", 1, 0);
	{
		const char* br = getenv("NEATVNC_BITRATE_KBPS");
		const char* fr = getenv("NEATVNC_FRAMERATE");
		/* Without this the encoder derives ~65535 fps from the 1us time base and starves each frame. */
		self->codec_ctx->framerate = (AVRational){ fr ? atoi(fr) : 60, 1 };
		const char* lp = getenv("NEATVNC_LOW_POWER");
		if (br) {
			int64_t bps = (int64_t)atoi(br) * 1000;
			/* CBR with a ~1 frame VBV so the encoder never queues bursts */
			self->codec_ctx->bit_rate = bps;
			self->codec_ctx->rc_max_rate = bps;
			self->codec_ctx->rc_buffer_size = (int)(bps / 60);
			av_dict_set(&opts, "rc_mode", "CBR", 0);
		}
		if (lp)
			av_dict_set(&opts, "low_power", lp, 0);
	}'
    '';
  });

  # Forwards relative pointer events to the compositor via zwlr_virtual_pointer_v1.motion.
  # The dedupe patch fixes pointer_set() re-sending motion on every event (see the patch header); with one stream per
  # display that made a button release warp the shared cursor back to the releasing stream's last position.
  wayvnc = prev.wayvnc.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/wayvnc-relative-pointer.patch
      ../patches/wayvnc-pointer-dedupe.patch
    ];
  });
}
