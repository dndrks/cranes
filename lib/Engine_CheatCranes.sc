Engine_CheatCranes : CroneEngine {
	var kernel, debugPrinter;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		kernel = CheatCranes.new(Crone.server);

		this.addCommand(\trig, "sfsi", { arg msg;
			var k = msg[1].asSymbol;
			var velocity = msg[2].asFloat;
			var retrigFlag = msg[3].asSymbol;
			var allocVoice = msg[4].asInteger-1;
			kernel.test_trigger(k,velocity,allocVoice);
		});

		this.addCommand(\set_voice_param, "ssf", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var paramKey = msg[2].asSymbol;
			var paramValue = msg[3].asFloat;
			kernel.setVoiceParam(voiceKey, paramKey, paramValue);
		});

		this.addCommand(\set_poly_voice_param, "iisf", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var allocVoice = msg[2].asInteger-1;
			var paramKey = msg[3].asSymbol;
			var paramValue = msg[4].asFloat;
			kernel.setPolyVoiceParam(voiceKey, allocVoice, paramKey, paramValue);
		});

		this.addCommand(\set_delay_param, "sf", {arg msg;
			var paramKey = msg[1].asSymbol;
			var paramValue = msg[2].asFloat;
			kernel.setDelayParam(paramKey, paramValue);
		});

		this.addCommand(\set_reverb_param, "sf", {arg msg;
			var paramKey = msg[1].asSymbol;
			var paramValue = msg[2].asFloat;
			kernel.setReverbParam(paramKey, paramValue);
		});

		this.addCommand(\set_feedback_param, "ssf", {arg msg;
			var targetKey = msg[1].asSymbol;
			var paramKey = msg[2].asSymbol;
			var paramValue = msg[3].asFloat;
			kernel.setFeedbackParam(targetKey, paramKey, paramValue);
		});

		this.addCommand(\set_main_param, "sf", {arg msg;
			var paramKey = msg[1].asSymbol;
			var paramValue = msg[2].asFloat;
			kernel.setMainParam(paramKey, paramValue);
		});

		this.addCommand(\load_file, "ss", { arg msg;
			kernel.loadFile(msg);
		});

		this.addCommand(\load_folder, "ss", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var filepath = msg[2].asSymbol;
			kernel.loadFolder(voiceKey, filepath);
		});

		this.addCommand(\change_sample, "si", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var sample = msg[2].asInteger;
			kernel.setFile(voiceKey, sample, false);
		});

		this.addCommand(\stop_sample, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.stopSample(voiceKey);
		});

		this.addCommand(\set_sample_bounds, "isfi", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var paramKey = msg[2].asSymbol;
			var paramValue = msg[3].asFloat;
			var allocVoice = msg[4].asInteger-1;
			kernel.setSampleBounds(voiceKey, paramKey, paramValue, allocVoice);
		});

		this.addCommand(\set_sample_loop, "ii", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var allocVoice = msg[2].asInteger-1;
			kernel.setSampleLoop(voiceKey, allocVoice);
		});

		this.addCommand(\set_sample_rate, "iif", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var allocVoice = msg[2].asInteger-1;
			var paramValue = msg[3].asFloat;
			kernel.setSampleRate(voiceKey, allocVoice, paramValue);
		});

		this.addCommand(\clear_samples, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.clearSamples(voiceKey);
		});

		this.addCommand(\set_model, "sss", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var synthKey = msg[2].asSymbol;
			var reseed = msg[3].asSymbol;
			kernel.setModel(voiceKey,synthKey,reseed);
		});

		this.addCommand(\free_voice, "s", { arg msg;
			var voiceKey = msg[1].asSymbol;
			kernel.freeVoice(voiceKey);
		});

		this.addCommand(\init_voice, "ss", { arg msg;
			var voiceKey = msg[1].asSymbol;
			var synthKey = msg[2].asSymbol;
			kernel.initVoice(voiceKey, synthKey);
		});

		this.addCommand(\set_voice_limit, "ii", { arg msg;
			var voice = msg[1].asSymbol;
			var limit = msg[2].asInteger;
			kernel.setVoiceLimit(voice, limit);
		});

		this.addCommand(\set_sample_mode, "is", { arg msg;
			var voice = msg[1].asSymbol;
			var mode = msg[2].asSymbol;
			kernel.setSampleMode(voice,mode);
		});

		this.addCommand(\set_poly_param_style, "is", { arg msg;
			var voice = msg[1].asSymbol;
			var style = msg[2].asString;
			kernel.setPolyParamStyle(voice, style);
		});

		this.addCommand(\save_poly_params, "s", { arg msg;
			kernel.savePolyParams(msg[1].asString);
		});

		this.addCommand(\load_poly_params, "s", { arg msg;
			kernel.loadPolyParams(msg[1].asString);
		});

		this.addCommand(\free_feedback,"", {
			kernel.freeFeedback();
		});

		this.addCommand(\init_feedback,"", {
			kernel.initFeedback();
		});

		this.addCommand(\pset_switch,"", {
			kernel.psetSwitch();
		});

		this.addCommand(\reset,"", {
			kernel.resetVoices();
			kernel.resetParams();
			kernel.resetBuffers();
		});
	}

	free {
		kernel.free;
	}
}