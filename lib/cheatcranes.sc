CheatCranes {
	classvar <voiceKeys;
	classvar <synthDefs;

	var <synthKeys;
	var <paramProtos;
	var <generalizedParams;
	var <polyParamStyle;
	var <polyParams;
	var <groups;
	var <topGroup;

	var <outputSynths;
	var <feedbackSynths;
	var <feedbackEnabled;
	var <busses;
	var <delayBufs;
	var <delayParams;
	var <mainOutParams;

	var <voiceTracker;
	var <emptyVoices;
	var <folderedSamples;
	var <voiceLimit;
	classvar <sampleInfo;
	classvar <indexTracker;

	*new {
		voiceKeys = [ \1, \2, \3, \4, \5, \6, \7, \8];
		synthDefs = Dictionary.new;
		synthDefs[\sample] = CCSample.new(Server.default);
		synthDefs[\sampleFolder] = CCSampleFolder.new(Server.default);
		synthDefs[\samplePlaythrough] = CCSamplePlaythrough.new(Server.default);

		^super.new.init;
	}

	init {
		var s = Server.default, sample_iterator = 1;

		synthKeys = Dictionary.newFrom([
			\1, \none,
			\2, \none,
			\3, \none,
			\4, \none,
			\5, \none,
			\6, \none,
			\7, \none,
			\8, \none,
		]);

		outputSynths = Dictionary.new;
		feedbackSynths = Dictionary.new;

		voiceTracker = Dictionary.new;
		voiceLimit = Dictionary.newFrom([
			\1, 1,
			\2, 1,
			\3, 1,
			\4, 1,
			\5, 1,
			\6, 1,
			\7, 1,
			\8, 1,
		]);
		polyParams = Dictionary.new(voiceKeys.size);
		polyParamStyle = Dictionary.newFrom([
			\1, "all voices",
			\2, "all voices",
			\3, "all voices",
			\4, "all voices",
			\5, "all voices",
			\6, "all voices",
			\7, "all voices",
			\8, "all voices",
		]);
		emptyVoices = Dictionary.new;
		(1..8).do{arg i; emptyVoices[i] = false};
		indexTracker = Dictionary.new;

		folderedSamples = Dictionary.new;
		sampleInfo = Dictionary.newFrom([
			\1, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\2, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\3, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\4, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\5, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\6, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\7, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
			\8, Dictionary.newFrom(
				[
					\samples, Dictionary.new(),
					\pointers, Dictionary.new(),
					\samplerates, Dictionary.new()
			]),
		]);

		groups = Dictionary.new;
		voiceKeys.do({ arg voiceKey;
			indexTracker[voiceKey] = 0;
			polyParams[voiceKey] = Dictionary.new(8);
			8.do{ arg i;
				voiceTracker[voiceKey] = Dictionary.new(8);
				polyParams[voiceKey][i] = Dictionary.new;
			};
		});

		delayBufs = Dictionary.new;
		delayBufs[\left1] = Buffer.alloc(s, s.sampleRate * 24.0, 2);
		delayBufs[\right] = Buffer.alloc(s, s.sampleRate * 24.0, 2);

		busses = Dictionary.new;
		busses[\mainOut] = Bus.audio(s, 2);
        busses[\feedbackSend] = Bus.audio(s, 2);

		busses[\out1] = Bus.audio(s,2);
		busses[\out2] = Bus.audio(s,2);
		busses[\out3] = Bus.audio(s,2);
		busses[\feedback1] = Bus.audio(s,2);
		busses[\feedback2] = Bus.audio(s,2);
		busses[\feedback3] = Bus.audio(s,2);
		busses[\feedbackSend1] = Bus.audio(s,2);
		busses[\feedbackSend2] = Bus.audio(s,2);
		busses[\feedbackSend3] = Bus.audio(s,2);
		~feedback = Group.new(addAction:'addToTail');
		~mixer = Group.new(~feedback, \addAfter);
		~processing = Group.new(~mixer, \addAfter);
		~main = Group.new(~processing, \addAfter);

		// feedback matrix
		// based on WazMatrix Mixer V.1, by scacinto

		// ** inFeedback
		SynthDef("feedback1", {
			var in = InFeedback.ar(busses[\feedback1],2);
			in = LeakDC.ar(in);
			in = Limiter.ar(in,0.25);
			Out.ar(busses[\feedbackSend1], in);
		}).add;

		SynthDef("feedback2", {
			var in = InFeedback.ar(busses[\feedback2],2);
			in = LeakDC.ar(in);
			in = Limiter.ar(in,0.25);
			Out.ar(busses[\feedbackSend2], in);
		}).add;

		SynthDef("feedback3", {
			var in = InFeedback.ar(busses[\feedback3],2);
			in = LeakDC.ar(in);
			in = Limiter.ar(in,0.25);
			Out.ar(busses[\feedbackSend3], in);
		}).add;

		// ** MAIN OUT
		SynthDef("mainMixer", {
			arg inA = 0, inB = 0, inC = 0,
			mixSpread = 1, mixCenter = 0, mixLevel = 1,
			lSHz = 600, lSdb = 0.0, lSQ = 50,
			hSHz = 19000, hSdb = 0.0, hSQ = 50;
			var outa, outb, outc, sound;

			outa = Mix.ar(In.ar(busses[\feedback1], 2) * inA);
			outb = Mix.ar(In.ar(busses[\feedback2], 2) * inB);
			outc = Mix.ar(In.ar(busses[\feedback3], 2) * inC);

			sound = Splay.ar([outa, outb, outc],spread: mixSpread, level: mixLevel, center: mixCenter);
			sound = BLowShelf.ar(sound, lSHz, lSQ, lSdb);
			sound = BHiShelf.ar(sound, hSHz, hSQ, hSdb);
			sound = Limiter.ar(sound, 0.25);

			sound = LeakDC.ar(sound);

			Out.ar(busses[\mainOut], sound);
		}).add;

		// ** CHANNEL MIXERS
		SynthDef("input1Mixer", {
			arg inAmp = 1, outAmp = 1, inA = 0, inB = 0, inC = 0, outA = 1, outB = 0, outC = 0;
			var in1Src, sound, in1A, in1B, in1C, mix, out1, out2, out3;

			in1Src = In.ar(busses[\feedbackSend],2) * inAmp;

			in1A = In.ar(busses[\feedbackSend1], 2);
			in1B = In.ar(busses[\feedbackSend2], 2);
			in1C = In.ar(busses[\feedbackSend3], 2);

			in1A = in1A * inA;
			in1B = in1B * inB;
			in1C = in1C * inC;

			mix = Mix([in1Src, in1A, in1B, in1C]).clip;

			Out.ar(busses[\out1], mix * outA * outAmp);
			Out.ar(busses[\out2], mix * outB * outAmp);
			Out.ar(busses[\out3], mix * outC * outAmp);

		}).add;

		SynthDef("input2Mixer", {
			arg inAmp = 1, outAmp = 1, inA = 0, inB = 0, inC = 0, outA = 0, outB = 1, outC = 0;
			var in2Src, sound, in2A, in2B, in2C, mix, out1, out2, out3;

			in2Src = In.ar(busses[\feedbackSend],2) * inAmp;

			in2A = In.ar(busses[\feedbackSend1], 2);
			in2B = In.ar(busses[\feedbackSend2], 2);
			in2C = In.ar(busses[\feedbackSend3], 2);

			in2A = in2A * inA;
			in2B = in2B * inB;
			in2C = in2C * inC;

			mix = Mix([in2Src, in2A, in2B, in2C]).clip;

			out1 = Out.ar(busses[\out1], mix * outA * outAmp);
			out2 = Out.ar(busses[\out2], mix * outB * outAmp);
			out3 = Out.ar(busses[\out3], mix * outC * outAmp);

		}).add;

		SynthDef("input3Mixer", {
			arg inAmp = 1, outAmp = 1, inA = 0, inB = 0, inC = 0, outA = 0, outB = 0, outC = 1;
			var in3Src, sound, in3A, in3B, in3C, mix, out1, out2, out3;

			in3Src = In.ar(busses[\feedbackSend],2) * inAmp;

			in3A = In.ar(busses[\feedbackSend1], 2);
			in3B = In.ar(busses[\feedbackSend2], 2);
			in3C = In.ar(busses[\feedbackSend3], 2);

			in3A = in3A * inA;
			in3B = in3B * inB;
			in3C = in3C * inC;

			mix = Mix([in3Src, in3A, in3B, in3C]).clip;

			out1 = Out.ar(busses[\out1], mix * outA * outAmp);
			out2 = Out.ar(busses[\out2], mix * outB * outAmp);
			out3 = Out.ar(busses[\out3], mix * outC * outAmp);

		}).add;

		//** PROCESSORS
		SynthDef("processA", {
			arg delayTime = 0.1, delayAmp = 1,
			shiftFreq = 0,
			lSHz = 600, lSdb = 0.0, lSQ = 50,
			hSHz = 19000, hSdb = 0.0, hSQ = 50,
			eqHz = 6000, eqdb = 0.0, eqQ = 0.0;
			var in, sound;

			in = In.ar(busses[\out1],2);

			lSHz = lSHz.lag3(0.1);
			hSHz = hSHz.lag3(0.1);
			eqHz = eqHz.lag3(0.1);
			lSdb = lSdb.lag3(0.1);
			hSdb = hSdb.lag3(0.1);
			eqdb = eqdb.lag3(0.1);
			delayTime = delayTime.lag3(0.2);
			lSQ = LinLin.kr(lSQ,0,100,1.0,0.3);
			hSQ = LinLin.kr(hSQ,0,100,1.0,0.3);
			eqQ = LinLin.kr(eqQ,0,100,1.0,0.1);

			sound = DelayC.ar(in, 3, delayTime, delayAmp);
			sound = FreqShift.ar(sound, shiftFreq);
			sound = BLowShelf.ar(sound, lSHz, lSQ, lSdb);
			sound = BHiShelf.ar(sound, hSHz, hSQ, hSdb);

			Out.ar(busses[\feedback1], sound.tan);
		}).add;

		SynthDef("processB", {
			arg delayTime = 0.1, delayAmp = 1,
			shiftFreq = 0,
			lSHz = 600, lSdb = 0.0, lSQ = 50,
			hSHz = 19000, hSdb = 0.0, hSQ = 50,
			eqHz = 6000, eqdb = 0.0, eqQ = 0.0;
			var in, sound;

			in = In.ar(busses[\out2],2);

			lSHz = lSHz.lag3(0.1);
			hSHz = hSHz.lag3(0.1);
			eqHz = eqHz.lag3(0.1);
			lSdb = lSdb.lag3(0.1);
			hSdb = hSdb.lag3(0.1);
			eqdb = eqdb.lag3(0.1);
			delayTime = delayTime.lag3(0.2);
			lSQ = LinLin.kr(lSQ,0,100,1.0,0.3);
			hSQ = LinLin.kr(hSQ,0,100,1.0,0.3);
			eqQ = LinLin.kr(eqQ,0,100,1.0,0.1);

			sound = DelayC.ar(in, 3, delayTime, delayAmp);
			sound = FreqShift.ar(sound, shiftFreq);
			sound = BLowShelf.ar(sound, lSHz, lSQ, lSdb);
			sound = BHiShelf.ar(sound, hSHz, hSQ, hSdb);

			Out.ar(busses[\feedback2], sound.tan);
		}).add;

		SynthDef("processC", {
			arg delayTime = 0.1, delayAmp = 1,
			shiftFreq = 0,
			lSHz = 600, lSdb = 0.0, lSQ = 50,
			hSHz = 19000, hSdb = 0.0, hSQ = 50,
			eqHz = 6000, eqdb = 0.0, eqQ = 0.0;
			var in, sound;

			in = In.ar(busses[\out3],2);

			lSHz = lSHz.lag3(0.1);
			hSHz = hSHz.lag3(0.1);
			eqHz = eqHz.lag3(0.1);
			lSdb = lSdb.lag3(0.1);
			hSdb = hSdb.lag3(0.1);
			eqdb = eqdb.lag3(0.1);
			delayTime = delayTime.lag3(0.2);
			lSQ = LinLin.kr(lSQ,0,100,1.0,0.3);
			hSQ = LinLin.kr(hSQ,0,100,1.0,0.3);
			eqQ = LinLin.kr(eqQ,0,100,1.0,0.1);

			sound = DelayC.ar(in, 3, delayTime, delayAmp);
			sound = FreqShift.ar(sound, shiftFreq);
			sound = BLowShelf.ar(sound, lSHz, lSQ, lSdb);
			sound = BHiShelf.ar(sound, hSHz, hSQ, hSdb);

			Out.ar(busses[\feedback3], sound.tan);
		}).add;

		s.sync;

		feedbackSynths[\aFeedback] = Synth("feedback1", target: ~feedback);
		feedbackSynths[\bFeedback] = Synth("feedback2", target: ~feedback);
		feedbackSynths[\cFeedback] = Synth("feedback3", target: ~feedback);
		feedbackSynths[\aMixer] = Synth(\input1Mixer, target: ~mixer);
		feedbackSynths[\bMixer] = Synth(\input2Mixer, target: ~mixer);
		feedbackSynths[\cMixer] = Synth(\input3Mixer, target: ~mixer);
		feedbackSynths[\aProcess] = Synth(\processA, target: ~processing);
		feedbackSynths[\bProcess] = Synth(\processB, target: ~processing);
		feedbackSynths[\cProcess] = Synth(\processC, target: ~processing);
		feedbackSynths[\mainMixer] = Synth(\mainMixer, target: ~main);
		feedbackEnabled = true;
		// \ feedback

		s.sync;

		busses[\delayLSend] = Bus.audio(s, 1);
		busses[\delayRSend] = Bus.audio(s, 1);

		delayParams = Dictionary.newFrom([
			\time, 0.8,
			\level, 1,
			\feedback, 0.7,
			\spread, 1,
			\pan, 0,
			\lpHz, 20000,
			\hpHz, 20,
			\filterQ, 50,
			\feedbackSend, 0
		]);

		mainOutParams = Dictionary.newFrom([
			\lSHz, 600,
			\lSdb, 0,
			\lSQ, 50,
			\hSHz, 19000,
			\hSdb, 0,
			\hSQ, 50,
			\eqHz, 6000,
			\eqdb, 0,
			\eqQ, 50,
			\level, 1,
			\limiterLevel, 0.5
		]);

		generalizedParams = Dictionary.newFrom([
			\sample, CCSample.buildParams(
				nil,
				busses[\mainOut],
				busses[\delayLSend],
				busses[\delayRSend],
				busses[\feedbackSend],
			),
			\sampleFolder, CCSampleFolder.buildParams(
				nil,
				busses[\mainOut],
				busses[\delayLSend],
				busses[\delayRSend],
				busses[\feedbackSend],
			),
			\samplePlaythrough, CCSamplePlaythrough.buildParams(
				nil,
				busses[\mainOut],
				busses[\delayLSend],
				busses[\delayRSend],
				busses[\feedbackSend],
			),
		]);

		paramProtos = Dictionary.newFrom([
			\1, Dictionary.newFrom(generalizedParams[\sample]),
			\2, Dictionary.newFrom(generalizedParams[\sample]),
			\3, Dictionary.newFrom(generalizedParams[\sample]),
			\4, Dictionary.newFrom(generalizedParams[\sample]),
			\5, Dictionary.newFrom(generalizedParams[\sample]),
			\6, Dictionary.newFrom(generalizedParams[\sample]),
			\7, Dictionary.newFrom(generalizedParams[\sample]),
			\8, Dictionary.newFrom(generalizedParams[\sample]),
		]);

		outputSynths[\delay] = SynthDef.new(\delay, {

			arg time = 0.3, level = 1.0, feedback = 0.7,
			lpHz = 20000, hpHz = 20, filterQ = 50,
			spread = 1, pan = 0,
			feedbackSend = 0,
			inputL, inputR,
			mainOutput, feedbackOutput;

			var delayL, delayR,
			localin, del, input;

			time = time.lag3(0.2);
			feedback = feedback.lag3(0.1);
			lpHz = lpHz.lag3(0.05);
			hpHz = hpHz.lag3(0.05);
			level = level.lag3(0.1);

			input = In.ar(inputL,2); // TODO GENERALIZE IN SYNTHS, SHOULDN'T MATTER WHICH PANNING...
			localin = LocalIn.ar(2);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);

			// thank you ezra for https://github.com/catfact/engine-intro/blob/master/EngineIntro_NoiseSine.sc#L35-L49
			delayL = BufDelayC.ar(delayBufs[\left1].bufnum, input[0] + (feedback * localin[1]), time, 1);
			delayR = BufDelayC.ar(delayBufs[\right].bufnum, (feedback * localin[0]), time, 1);

			del = [delayL, delayR];
			LocalOut.ar(del);

			del = Splay.ar(del,spread,1);
			del = RLPF.ar(in:del, freq:lpHz, rq: filterQ, mul:1);
			del = RHPF.ar(in:del, freq:hpHz, rq: filterQ, mul:1);
			del = Balance2.ar(del[0],del[1],pan);

			Out.ar(mainOutput, del * level); // level down here, so the delays continue
			Out.ar(feedbackOutput,del * level * feedbackSend);

        }).play(target:s, addAction:\addToTail, args:[
			\inputL, busses[\delayLSend],
			\inputR, busses[\delayRSend],
			\feedbackOutput, busses[\feedbackSend],
			\mainOutput, busses[\mainOut]
        ]);

        outputSynths[\main] = SynthDef.new(\main, {
            arg in, out,
			lSHz = 600, lSdb = 0.0, lSQ = 50,
			hSHz = 19000, hSdb = 0.0, hSQ = 50,
			eqHz = 6000, eqdb = 0.0, eqQ = 0.0,
			level = 1.0, limiterLevel = 0.5;
			var src = In.ar(in, 2);

			lSHz = lSHz.lag3(0.1);
			hSHz = hSHz.lag3(0.1);
			eqHz = eqHz.lag3(0.1);
			lSdb = lSdb.lag3(0.1);
			hSdb = hSdb.lag3(0.1);
			eqdb = eqdb.lag3(0.1);
			level = level.lag3(0.1);

			lSQ = LinLin.kr(lSQ,0,100,1.0,0.3);
			hSQ = LinLin.kr(hSQ,0,100,1.0,0.3);
			eqQ = LinLin.kr(eqQ,0,100,1.0,0.1);

			src = BLowShelf.ar(src, lSHz, lSQ, lSdb);
			src = BHiShelf.ar(src, hSHz, hSQ, hSdb);
			src = BPeakEQ.ar(src, eqHz, eqQ, eqdb);
			src = Limiter.ar(src, limiterLevel);

			Out.ar(out, src * level);
        }).play(target:s, addAction:\addToTail, args: [
            \in, busses[\mainOut], \out, 0
        ]);

	}

	triggerSample { arg voiceKey, velocity, allocVoice;
		Server.default.makeBundle(nil,{
			voiceTracker[voiceKey][allocVoice].set(\velocity, velocity);
			voiceTracker[voiceKey][allocVoice].set(\t_gate, 1);
			voiceTracker[voiceKey][allocVoice].set(\t_trig, 1);
			('triggering sample '++allocVoice).postln;
			this.setSampleLoop(voiceKey, allocVoice);
		});
	}

	test_trigger { arg voiceKey, velocity, allocVoice;

		paramProtos[voiceKey][\velocity] = velocity;
		indexTracker[voiceKey] = allocVoice;
		('should trigger').postln;
		if (voiceTracker[voiceKey][allocVoice].isPlaying, {
			this.triggerSample(voiceKey, velocity, allocVoice);
		});
	}

	setSampleLoop {
		arg voiceKey, allocVoice;
		var frames, start, end, duration, rate;

		polyParams[voiceKey][allocVoice][\looper].stop;

		if (voiceTracker[voiceKey][allocVoice].isPlaying && (polyParams[voiceKey][allocVoice][\loop] == 1), {
			frames = polyParams[voiceKey][allocVoice][\bufnum].numFrames;

			polyParams[voiceKey][allocVoice][\looper] = Routine({
				loop{
					('looping sample '++allocVoice).postln;
					start = polyParams[voiceKey][allocVoice][\sampleStart];
					end = polyParams[voiceKey][allocVoice][\sampleEnd];
					rate = polyParams[voiceKey][allocVoice][\rate];

					duration = frames*(end-start)/(rate).abs/Server.default.sampleRate;
					duration.wait;
					voiceTracker[voiceKey][allocVoice].set(\t_gate, 1);
					voiceTracker[voiceKey][allocVoice].set(\t_trig, 1);
				}
			}).play;

		});
	}

	setSampleBounds { arg voiceKey, paramKey, paramValue, allocVoice;
		if( voiceTracker[voiceKey][allocVoice].isPlaying,
			{
				('setting '++ paramKey ++ ' ' ++ allocVoice ++ ' ' ++paramValue).postln;
				voiceTracker[voiceKey][allocVoice].set(paramKey, paramValue);
				polyParams[voiceKey][allocVoice][paramKey] = paramValue;
			}
		);
	}

	setSampleRate { arg voiceKey, allocVoice, paramValue;
		var frames, start, end, duration, rate;
		if( voiceTracker[voiceKey][allocVoice].isPlaying,
			{
				frames = polyParams[voiceKey][allocVoice][\bufnum].numFrames;
				if( paramValue >= 0,
					{voiceTracker[voiceKey][allocVoice].set(\startPos, 0.0)},
					{voiceTracker[voiceKey][allocVoice].set(\startPos, frames - 1)}
				);
				voiceTracker[voiceKey][allocVoice].set(\rate,paramValue);
			}
		);
	}

	setVoiceParam { arg voiceKey, paramKey, paramValue;
		paramProtos[voiceKey][paramKey] = paramValue;

		if( voiceLimit[voiceKey] == 1,
			{ // if mono:
				if( voiceTracker[voiceKey][indexTracker[voiceKey]].isPlaying,
					{
						voiceTracker[voiceKey][indexTracker[voiceKey]].set(paramKey, paramValue);
						if( (paramKey.asString).contains("rate"),
							// {this.setSampleLoop(voiceKey,indexTracker[voiceKey])}
						);
					}
				);
				8.do({ arg i;
					polyParams[voiceKey][i][paramKey] = paramValue; // write to poly voice storage
				});
			},
			{ // if poly:
				case
				{(paramKey.asString).contains("sampleStart") || (paramKey.asString).contains("sampleEnd")}
				{
					var current = indexTracker[voiceKey];
					('voiceKey: '++ current).postln;
					(voiceTracker[voiceKey][current]).postln;
					if( voiceTracker[voiceKey][current].isPlaying,
						{
							voiceTracker[voiceKey][current].set(paramKey, paramValue);
							polyParams[voiceKey][current][paramKey] = paramValue;
						}
					);
				}
				{(paramKey.asString).contains("rate_maybe?") == false}
				{
					case
					{ polyParamStyle[voiceKey] == "all voices"}{
						(voiceLimit[voiceKey]).do{ arg i;
							if( voiceTracker[voiceKey][i].isPlaying,
								{
									voiceTracker[voiceKey][i].set(paramKey, paramValue);
								}
							);
						};
						8.do({ arg i; // write to all poly voice storage
							polyParams[voiceKey][i][paramKey] = paramValue;
						});
					}
					// set parameters for the current voice:
					{ polyParamStyle[voiceKey] == "current voice"}{
						var current = indexTracker[voiceKey];
						if( voiceTracker[voiceKey][current].isPlaying,
							{
								voiceTracker[voiceKey][current].set(paramKey, paramValue);
								polyParams[voiceKey][current][paramKey] = paramValue;
							}
						);
					}
					// set parameters for the next voice:
					{ polyParamStyle[voiceKey] == "next voice"}{
						var next = (indexTracker[voiceKey] + 1) % voiceLimit[voiceKey];
						if( voiceTracker[voiceKey][next].isPlaying,
							{
								voiceTracker[voiceKey][next].set(paramKey, paramValue);
								polyParams[voiceKey][next][paramKey] = paramValue;

							}
						);
					};
				}
			}
		);
	}

	setPolyVoiceParam{ arg voiceKey, allocVoice, paramKey, paramValue;
		if ( (paramKey.asString).contains("rate_maybe"), {
			if( voiceTracker[voiceKey][allocVoice].isPlaying,
				{voiceTracker[voiceKey][allocVoice].set(paramKey, paramValue)}
			);
		},{
			if( voiceTracker[voiceKey][allocVoice].isPlaying,
				{
					voiceTracker[voiceKey][allocVoice].set(paramKey, paramValue);
				}
			);
			polyParams[voiceKey][allocVoice][paramKey] = paramValue;
		});
	}

	savePolyParams {
		arg pathname;
		polyParams.writeArchive(pathname);
	}

	loadPolyParams {
		arg pathname;
		polyParams = Object.readArchive(pathname);
		polyParams.pairsDo({arg voiceKey, voiceID;
			voiceID.pairsDo({arg key,val;
				if( voiceTracker[voiceKey][key].isPlaying,
					{
						if( voiceKey == \1,{key.postln});
						val.pairsDo({ arg name, value;
							voiceTracker[voiceKey][key].set(name, value);
						});
					}
				);
			});
		});
	}

	setDelayParam { arg paramKey, paramValue;
		delayParams[paramKey] = paramValue;
		outputSynths[\delay].set(paramKey, paramValue);
	}

	setFeedbackParam { arg targetKey, paramKey, paramValue;
		feedbackSynths[(targetKey).asSymbol].set(paramKey, paramValue);
	}

	setMainParam { arg paramKey, paramValue;
		mainOutParams[paramKey] = paramValue;
		outputSynths[\main].set(paramKey, paramValue);
	}

	allNotesOff {
		// topGroup.set(\stopGate, 0);
	}

	freeVoice { arg voiceKey;
		(voiceLimit[voiceKey]).do({ arg voiceIndex;
			if (voiceTracker[voiceKey][voiceIndex].isPlaying, {
				voiceTracker[voiceKey][voiceIndex].set(\t_gate, -1.1);
				Routine {
					0.15.wait;
					voiceTracker[voiceKey][voiceIndex].free;
				}.play;
			});
		});
		emptyVoices[voiceKey] = true;
	}

	initVoice { arg voice, model;
		emptyVoices[voice] = false;
		('initializing '++voice++', '++model).postln;
		this.setModel(voice, model, 'true');
	}

	setVoiceLimit { arg voice, limit;
		var prevPoly = voiceLimit[voice];

		// - check to see if old voices (greater than the new limit) need to be cleared out
		// - instantiate any new voices needed (up to the new limit)

		if( limit < prevPoly, {
			('should remove poly voices '++limit ++ ' '++prevPoly).postln;
			(prevPoly..limit+1).do({ arg voiceIndex;
				if (voiceTracker[voice][voiceIndex-1].isPlaying, {
					voiceTracker[voice][voiceIndex-1].set(\t_gate, -1.1);
					Routine {
						0.15.wait;
						voiceTracker[voice][voiceIndex-1].free;
					}.play;
					('looks like '++voice++', '++(voiceIndex-1)++' needed to be freed: 760').postln;
				});
			});
		},{
			(prevPoly+1..limit).do({ arg voiceIndex;
				if( emptyVoices[voice] == false, {
					voiceTracker[voice][voiceIndex-1] = Synth.new(
						synthKeys[voice],
						polyParams[voice][voiceIndex-1].getPairs
					);
					NodeWatcher.register(voiceTracker[voice][voiceIndex-1],true);
					(voiceIndex-1).postln;
				});
			});
		});

		voiceLimit[voice] = limit;
		indexTracker[voice] = limit-1; // TODO 230131: this shouldn't be just 'limit', right?
	}

	setPolyParamStyle { arg voice, style;
		polyParamStyle[voice] = style;
	}

	clearSamples { arg voice;
		8.do({ arg allocVoice;
			polyParams[voice][allocVoice.asInteger][\looper].stop;
		});
		("clearSamples: " ++ voice).postln;
		if ( sampleInfo[voice][\samples].size > 0, {
			for ( 0, sampleInfo[voice][\samples].size-1, {
				arg i;
				sampleInfo[voice][\samples][i].free;
				sampleInfo[voice][\samples][i] = nil;
				("freeing buffer "++i).postln;
			});
		});
	}

	loadFile { arg msg;
		var voice = msg[1], filename = msg[2];

		voice.postln;
		indexTracker.postln;
		indexTracker[voice].postln;
		voiceTracker[voice][indexTracker[voice]].set(\t_gate, -1);
		voiceTracker[voice][indexTracker[voice]].set(\t_trig, -1);

		this.clearSamples(voice);
		sampleInfo[voice][\samples][0] = Buffer.read(Server.default, filename ,action:{
			arg bufnum;
			sampleInfo[voice][\pointers][0] = bufnum;
			this.setFile(voice,1,true);
		});
		('loadFile called').postln;
	}

	setFile { arg voice, samplenum, fromLoad;
		if ( sampleInfo[voice][\samples].size > 0, {
			samplenum = samplenum - 1;
			samplenum = samplenum.wrap(0,sampleInfo[voice][\samples].size-1);
			paramProtos[voice][\bufnum] = sampleInfo[voice][\pointers][samplenum];
			sampleInfo[voice][\samplerates][samplenum] = sampleInfo[voice][\samples][samplenum].sampleRate;
			paramProtos[voice][\channels] = sampleInfo[voice][\samples][samplenum].numChannels;
			if (fromLoad == true, {
				8.do({ arg alloc;
					voiceTracker[voice][alloc].set(\bufnum, sampleInfo[voice][\pointers][samplenum]);
					voiceTracker[voice][alloc].set(\channels, sampleInfo[voice][\samples][samplenum].numChannels);
					polyParams[voice][alloc][\bufnum] = sampleInfo[voice][\pointers][samplenum];
					polyParams[voice][alloc][\channels] = sampleInfo[voice][\samples][samplenum].numChannels;
					('setting buffer for ' ++ voice ++ ', ' ++ alloc ++ ': buffer ' ++ sampleInfo[voice][\pointers][samplenum]).postln;
				});
			},{
				voiceTracker[voice][indexTracker[voice]].set(\bufnum, sampleInfo[voice][\pointers][samplenum]);
				voiceTracker[voice][indexTracker[voice]].set(\channels, sampleInfo[voice][\samples][samplenum].numChannels);
				polyParams[voice][indexTracker[voice]][\bufnum] = sampleInfo[voice][\pointers][samplenum];
				polyParams[voice][indexTracker[voice]][\channels] = sampleInfo[voice][\samples][samplenum].numChannels;
			});
			('channel count: '++paramProtos[voice][\channels]).postln;
			// ('group: ' ++ groups[voice]).postln;
		});
	}

	loadFileIntoContainer { arg voice, index, path;
		sampleInfo[voice][\samples][index] = Buffer.read(Server.default, path, action:{
			arg bufnum;
			sampleInfo[voice][\pointers][index] = bufnum;
			('bufnum: ' ++ bufnum).postln;
			('pointers info: ' ++ sampleInfo[voice][\pointers][index]).postln;
			if (index == 0, {
				this.setFile(voice,1,true);
			});
		});
		('loadFileIntoContainer called').postln;
	}

	loadFolder { arg voice, filepath;
		this.clearSamples(voice);
		folderedSamples[voice] = SoundFile.collect(filepath++"*");
		for ( 0, folderedSamples[voice].size-1, {
			arg i;
			this.loadFileIntoContainer(voice,i,folderedSamples[voice][i].path);
		});
		('loadFolder called').postln;
	}

	setSampleMode { arg voice, model;
		(voiceLimit[voice]).do({ arg voiceIndex;
			if( voiceTracker[voice][voiceIndex].isPlaying, {
				voiceTracker[voice][voiceIndex].free;
				('freeing poly '++voiceTracker[voice][voiceIndex].nodeID).postln;
			});
		});
		synthKeys[voice] = model;
		paramProtos[voice] = Dictionary.newFrom(generalizedParams[model]);
		8.do({ arg i;
			('setting poly params ' ++ voice ++ ' ' ++i).postln;
			polyParams[voice][i] = Dictionary.newFrom(generalizedParams[model]);
		});
		('building synth ' ++ voice ++ ' ' ++ model).postln;
		(voiceLimit[voice]).do({ arg voiceIndex;
			voiceTracker[voice][voiceIndex] = Synth.new(synthKeys[voice], paramProtos[voice].getPairs);
			NodeWatcher.register(voiceTracker[voice][voiceIndex],true);
			('poly: '++ voice ++ ', ' ++ voiceIndex ++ ', '++voiceTracker[voice][voiceIndex].isPlaying).postln;
		});
	}

	/*adjustSampleMult { arg voice, mult;
		if (paramProtos[voice][\rate] != mult, {
			groups[voice].set(\rate, paramProtos[voice][\rate] * mult);
		});
	}*/

	/*adjustSampleOffset { arg voice, offset;
		groups[voice].set(\rate, (paramProtos[voice][\rate]) * (0.5**((offset*-1)/12)));
	}*/

	stopSample { arg voice;
		voiceTracker[voice][indexTracker[voice]].set(\t_gate, -1.1);
		voiceTracker[voice][indexTracker[voice]].set(\t_trig, -1.1);
	}

	freeFeedback{
		if ( feedbackEnabled == true, {
			feedbackSynths.do({arg bus;
				bus.free;
			});
			feedbackEnabled = false;
		});
	}

	initFeedback{ // TODO: when re-enabling, want to rebuild params from where we left off...
		if ( feedbackEnabled == false, {
			feedbackSynths[\aFeedback] = Synth("feedback1", target: ~feedback);
			feedbackSynths[\bFeedback] = Synth("feedback2", target: ~feedback);
			feedbackSynths[\cFeedback] = Synth("feedback3", target: ~feedback);
			feedbackSynths[\aMixer] = Synth(\input1Mixer, target: ~mixer);
			feedbackSynths[\bMixer] = Synth(\input2Mixer, target: ~mixer);
			feedbackSynths[\cMixer] = Synth(\input3Mixer, target: ~mixer);
			feedbackSynths[\aProcess] = Synth(\processA, target: ~processing);
			feedbackSynths[\bProcess] = Synth(\processB, target: ~processing);
			feedbackSynths[\cProcess] = Synth(\processC, target: ~processing);
			feedbackSynths[\mainMixer] = Synth(\mainMixer, target: ~main);
			feedbackEnabled = true;
		});
	}

	setModel { arg voice, model, reseed;
		var compileFlag = false;
		if (emptyVoices[voice] == false, {
			if (synthKeys[voice] != model,
				{
					compileFlag = true;
					(voiceLimit[voice]).do({ arg voiceIndex;
						if( voiceTracker[voice][voiceIndex].isPlaying, {
							voiceTracker[voice][voiceIndex].free;
							('freeing poly '++voiceTracker[voice][voiceIndex].nodeID).postln;
						});
					});
					synthKeys[voice] = model;
					('setModel...?' ++ model).postln;
					paramProtos[voice] = Dictionary.newFrom(generalizedParams[model]);
					('setModel??' ++ model).postln;
					8.do({ arg i;
						('setting poly params ' ++ voice ++ ' ' ++i).postln;
						polyParams[voice][i] = Dictionary.newFrom(generalizedParams[model]);
					});
				},
				{
					if (reseed == 'true',
						{compileFlag = true});
				}
			);
			if (compileFlag, {
				('building synth ' ++ voice ++ ' ' ++ model).postln;
				(voiceLimit[voice]).do({ arg voiceIndex;
					voiceTracker[voice][voiceIndex] = Synth.new(synthKeys[voice], paramProtos[voice].getPairs);
					NodeWatcher.register(voiceTracker[voice][voiceIndex],true);
					('poly: '++ voice ++ ', ' ++ voiceIndex ++ ', '++voiceTracker[voice][voiceIndex].isPlaying).postln;
				});
			});
		});
	}

	resetParams {
		voiceKeys.do({ arg voiceKey;
			indexTracker[voiceKey] = 0;
			polyParams[voiceKey] = Dictionary.new(8);
			8.do{ arg i;
				voiceTracker[voiceKey] = Dictionary.new(8);
				polyParams[voiceKey][i] = Dictionary.new;
			};
		});
	}

	resetVoices {
		voiceTracker.do({arg voice;
			(voice).do({ arg voiceIndex;
				voiceIndex.postln;
				if (voiceIndex.isPlaying, {
					('freeing voice '++voiceIndex).postln;
					voiceIndex.free;
				});
			});
		});
	}

	stopLoopers {
		('stopping loops').postln;
		(1..8).do({ arg voiceKey;
			(8).do({ arg allocVoice;
				polyParams[voiceKey.asSymbol][allocVoice.asInteger][\looper].stop;
			});
		});
	}

	resetBuffers {
		(1..8).do({arg voice; this.clearSamples(voice.asSymbol);})
	}

	psetSwitch {
		voiceTracker.do({arg voice;
			(voice).do({ arg voiceIndex;
				voiceIndex.postln;
				if (voiceIndex.isPlaying, {
					('freeing voice '++voiceIndex).postln;
					voiceIndex.free;
				});
			});
		});
		// 8.do({arg voice; this.clearSamples((voice+1).asSymbol);})
		// Buffer.freeAll(Crone.server);
	}

	free {
		this.stopLoopers;
		feedbackSynths.do({arg bus;
			bus.free;
		});
		~feedback.free;
		~mixer.free;
		~processing.free;
		~main.free;
		synthDefs.do({arg def;
			def.free;
		});
		voiceTracker.do({arg voice;
			(voice).do({ arg voiceIndex;
				voiceIndex.postln;
				if (voiceIndex.isPlaying, {
					('freeing voice '++voiceIndex).postln;
					voiceIndex.free;
				});
			});
		});
		busses.do({arg bus;
			bus.free;
		});
		outputSynths.do({arg bus;
			bus.free;
		});
		delayBufs.do({arg buf;
			buf.free;
		});
		Buffer.freeAll(Crone.server);
	}

}