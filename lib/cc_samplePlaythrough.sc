CCSamplePlaythrough {

	*new {
		arg srv;
		^super.new.init(srv);
	}

	*buildParams {
		arg bufnum, mainOutBus, delayLSendBus, delayRSendBus, feedbackSendBus;
		var returnTable;
		returnTable = Dictionary.newFrom([
			\bufnum, bufnum,
			\out,mainOutBus,
			\delayAuxL,delayLSendBus,
			\delayAuxR,delayRSendBus,
			\feedbackAux,feedbackSendBus,
			\channels,2,
			\delayEnv,0,
			\delayAtk,0,
			\delayRel,2,
			\delayCurve,-4,
			\delaySend,0,
			\feedbackEnv,0,
			\feedbackAtk,0,
			\feedbackRel,2,
			\feedbackCurve,-4,
			\feedbackSend,0,
			\amp,1,
			\loopAtk,0,
			\loopRel,50,
			\envStyle,0,
			\sampleStart,0,
			\sampleEnd,1,
			\loop,0,
			\rate,1,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,8175.08,
			\eqHz,6000,
			\eqAmp,0,
			\bitRate,24000,
			\bitCount,24,
			\lpHz,19000,
			\hpHz,20,
			\filterQ,50,
			\pan,0,
			\t_trig,1,
			\t_gate,0,
			\startA, 0,
			\startB, 0,
			\crossfade, 0,
			\aOrB, 0
		]);
		^returnTable
	}

	init {
		SynthDef(\samplePlaythrough, {
			arg bufnum, envStyle = 0, out = 0, amp = 1,
			t_trig = 1, t_gate = 0, loopAtk = 0, loopRel = 50,
			velocity = 127,
			sampleStart = 0, sampleEnd = 1,
			loop = 0, envCurve = -4,
			pan = 0,
			delayAuxL, delayAuxR, delaySend = 0,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux, feedbackSend = 0,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			channels = 2,
			rate = 1,
			amDepth, amHz,
			eqHz, eqAmp,
			bitRate, bitCount,
			lpHz, hpHz, filterQ,
			squishPitch, squishChunk;

			var snd;
			var frames, duration, loop_env, ampMod, delEnv, feedEnv, mainSend;

			eqHz = eqHz.lag3(0.01);
			lpHz = lpHz.lag3(0.01);
			hpHz = hpHz.lag3(0.01);
			delaySend = delaySend.lag3(0.01);
			feedbackSend = feedbackSend.lag3(0.01);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);

			rate = rate*BufRateScale.kr(bufnum);
			frames = BufFrames.kr(bufnum);

			duration = frames*(sampleEnd-sampleStart)/rate.abs/Server.default.sampleRate;

			loopAtk = LinLin.kr(loopAtk,0,100,0,duration/2);
			loopRel = LinLin.kr(loopRel,0,100,0,duration/2);

			loop_env = EnvGen.ar(
				Env(
					levels: [0,0,1,1,0],
					times: [0.01,loopAtk,duration-(loopAtk+loopRel),loopRel],
					curve: [0,envCurve*(-1),0,envCurve] // TODO: should envCurves be reversed?
				),
				gate: t_gate
			);

			snd = PlayBuf.ar(
				numChannels: 2,
				bufnum: bufnum,
				rate: rate,
				trigger: t_trig,
				startPos: sampleStart * frames
			) * loop_env;

			ampMod = SinOsc.ar(freq:amHz,mul:amDepth,add:1);

			mainSend = snd * ampMod;

			mainSend = Squiz.ar(in:mainSend, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			mainSend = Decimator.ar(mainSend,bitRate,bitCount,1.0);
			mainSend = BPeakEQ.ar(in:mainSend,freq:eqHz,rq:1,db:eqAmp,mul:1);
			mainSend = RLPF.ar(in:mainSend,freq:Clip.kr(lpHz, 20, 20000), rq: filterQ, mul:1);
			mainSend = RHPF.ar(in:mainSend,freq:hpHz, rq: filterQ, mul:1);

			if( channels == 2,
				{mainSend = Balance2.ar(mainSend[0],mainSend[1],pan)},
				{mainSend = Balance2.ar(mainSend[0],mainSend[0],pan)}
			);

			mainSend = mainSend * (amp * LinLin.kr(velocity,0,127,0.0,1.0));

			delEnv = delaySend * EnvGen.ar(
				envelope: Env.new(
					[1-delayEnv,1-delayEnv,1,1-delayEnv],
					times: [0.01,delayAtk,delayRel],
					curve: [0, delayCurve*(-1), delayCurve]),
				gate: t_gate
			);

			feedEnv = feedbackSend * EnvGen.ar(
				envelope: Env.new(
					[1-feedbackEnv,1-feedbackEnv,1,1-feedbackEnv],
					times: [0.01,feedbackAtk,feedbackRel],
					curve: [0, feedbackCurve*(-1), feedbackCurve]
				),
				gate: t_gate
			);


			Out.ar(out, mainSend);
			Out.ar(delayAuxL, (mainSend * delEnv));
			Out.ar(delayAuxR, (mainSend * delEnv));
			Out.ar(feedbackAux, (mainSend * (feedbackSend * feedEnv)));


		}).send;
	}
}