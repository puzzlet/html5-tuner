window.AudioContext = window.AudioContext or window.mozAudioContext or window.webkitAudioContext or window.msAudioContext or window.oAudioContext
navigator.getUserMedia = navigator.getUserMedia or navigator.mozGetUserMedia or navigator.webkitGetUserMedia or navigator.msGetUserMedia or navigator.oGetUserMedia



scale = document.querySelector ".scale"
labels = document.querySelector ".labels"
elVolume = document.querySelector ".volume"
canvas = document.querySelector "canvas"
elFreq = document.querySelector ".frequency .value"

prevNote = false

fadeOutInterval = null



paper = new Raphael document.querySelector(".svg"), 700, 400

# Scale
for i in [-40..40]
	if i == 0
		rect = paper.rect 350, 0, 2, 12
		rect.attr "fill": "rgba(255,255,255,1)"
	else if i % 16 == 0
		rect = paper.rect 350, 0, 1, 10
		rect.attr "fill": "rgba(255,255,255,1)"
	else if i % 2 == 0
		rect = paper.rect 350, 0, 1, 6
		rect.attr "fill": "rgba(255,255,255,0.7)"
	else
		rect = paper.rect 350, 2, 1, 2
		rect.attr "fill": "rgba(255,255,255,0.3)"

	rect.attr "stroke-width": 0, "opacity": Math.min(1, (-1 + 40/Math.abs(i))*2)
	rect.transform "r#{i},350,350"

# Needle
needle = paper.rect 350, 18, 2, 80
needle.attr "stroke-width": 0, "fill": "90-#111-#fff"




for i in [0..80]
	div = document.createElement "div"
	hr = document.createElement "hr"
	div.appendChild hr
	scale.appendChild div



precision = (x) ->
	Math.round(x*100) / 100



frequencies =
	'A0': 27.5, 'A1': 55, 'A2': 110, 'A3': 220, 'A4': 440, 'A5': 880, 'A6': 1760, 'A7': 3520.00
	'A#0': 29.1352, 'A#1': 58.2705, 'A#2': 116.541, 'A#3': 233.082, 'A#4': 466.164, 'A#5': 932.328, 'A#6': 1864.66, 'A#7': 3729.31
	'B0': 30.8677, 'B1': 61.7354, 'B2': 123.471, 'B3': 246.942, 'B4': 493.883, 'B5': 987.767, 'B6': 1975.53, 'B7': 3951.07
	'C1': 32.7032, 'C2': 65.4064, 'C3': 130.813, 'C4': 261.626, 'C5': 523.251, 'C6': 1046.50, 'C7': 2093, 'C8': 4186.01
	'C#1': 34.6478, 'C#2': 69.2957, 'C#3': 138.591, 'C#4': 277.183, 'C#5': 554.365, 'C#6': 1108.73, 'C#7': 2217.46
	'D1': 36.7081, 'D2': 73.4162, 'D3': 146.832, 'D4': 293.665, 'D5': 587.330, 'D6': 1174.66, 'D7': 2349.32
	'D#1': 38.8909, 'D#2': 77.7817, 'D#3': 155.563, 'D#4': 311.127, 'D#5': 622.254, 'D#6': 1244.51, 'D#7': 2489.02
	'E1': 41.2034, 'E2': 82.4069, 'E3': 164.814, 'E4': 329.628, 'E5': 659.255, 'E6': 1318.51, 'E7': 2637.02
	'F1': 43.6563, 'F2': 87.3071, 'F3': 174.614, 'F4': 349.228, 'F5': 698.456, 'F6': 1396.91, 'F7': 2793.83
	'F#1': 46.2493, 'F#2': 92.4986, 'F#3': 184.997, 'F#4': 369.994, 'F#5': 739.989, 'F#6': 1479.98, 'F#7': 2959.96
	'G1': 48.9994, 'G2': 97.9989, 'G3': 195.998, 'G4': 391.995, 'G5': 783.991, 'G6': 1567.98, 'G7': 3135.96
	'G#1': 51.9131, 'G#': 103.826, 'G#3': 207.652, 'G#4': 415.305, 'G#5': 830.609, 'G#6': 1661.22, 'G#7': 3322.44




context = canvas.getContext '2d'
audioContext = new AudioContext()


sampleRate = audioContext.sampleRate
fftSize = 8192
fft = new FFT(fftSize, sampleRate / 4)


buffer = (0 for i in [0...fftSize])
bufferFillSize = 2048
bufferFiller = audioContext.createScriptProcessor bufferFillSize, 1, 1
bufferFiller.onaudioprocess = (e) ->
	input = e.inputBuffer.getChannelData 0
	for b in [bufferFillSize...buffer.length]
		buffer[b - bufferFillSize] = buffer[b]
	for b in [0...input.length]
		buffer[buffer.length - bufferFillSize + b] = input[b]



volume = audioContext.createScriptProcessor 2048, 1, 1
volume.onaudioprocess = (e) ->
	input = e.inputBuffer.getChannelData 0
	total = 0
	total += Math.abs(i) for i in input
	average = total / input.length

	volumeIndicator = average * 10
	volumeIndicator = Math.max 0.05, volumeIndicator
	volumeIndicator = Math.min 1, volumeIndicator

	elVolume.style.borderColor = "rgba(255,255,255,#{volumeIndicator})"
	(document.querySelector ".debug-volume").innerHTML = precision average



gauss = new WindowFunction(DSP.GAUSS)


lp = audioContext.createBiquadFilter()
lp.type = lp.LOWPASS
lp.frequency = 8000
lp.Q = 0.1

hp = audioContext.createBiquadFilter()
hp.type = hp.HIGHPASS
hp.frequency = 20
hp.Q = 0.1


success = (stream) ->

	maxTime = 0
	noiseCount = 0
	noiseThreshold = -Infinity
	maxPeaks = 0
	maxPeakCount = 0


	src = audioContext.createMediaStreamSource stream
	src.connect lp
	src.connect volume
	volume.connect audioContext.destination
	lp.connect hp
	hp.connect bufferFiller
	bufferFiller.connect audioContext.destination


	process = ->

		bufferCopy = (b for b in buffer)

		gauss.process bufferCopy
	
		downsampled = []
		for s in [0...bufferCopy.length] by 4
			downsampled.push bufferCopy[s]
	
		upsampled = []
		for s in downsampled
			upsampled.push s
			upsampled.push 0
			upsampled.push 0
			upsampled.push 0
	
		fft.forward upsampled
	
		if noiseCount < 10
			noiseThreshold = Math.max(noiseThreshold, i) for i in fft.spectrum
			noiseThrehold = if noiseThreshold > 0.001 then 0.001 else noiseThreshold
			noiseCount++
	  
		spectrumPoints = (x: x, y: fft.spectrum[x] for x in [0...(fft.spectrum.length / 4)])
		spectrumPoints.sort (a, b) -> (b.y - a.y)
	
		peaks = []
		for p in [0...8]
			if spectrumPoints[p].y > noiseThreshold * 5
				peaks.push spectrumPoints[p]
		
		if peaks.length > 0
			for p in [0...peaks.length]
				if peaks[p]?
					for q in [0...peaks.length]
						if p isnt q and peaks[q]?
							if Math.abs(peaks[p].x - peaks[q].x) < 5
								peaks[q] = null
			peaks = (p for p in peaks when p?)
			peaks.sort (a, b) -> (a.x - b.x)
			
			maxPeaks = if maxPeaks < peaks.length then peaks.length else maxPeaks
			if maxPeaks > 0 then maxPeakCount = 0
			
			peak = null
			
			firstFreq = peaks[0].x * (sampleRate / fftSize)
			if peaks.length > 1
				secondFreq = peaks[1].x * (sampleRate / fftSize)
				if 1.4 < (firstFreq / secondFreq) < 1.6
					peak = peaks[1]
			if peaks.length > 2
				thirdFreq = peaks[2].x * (sampleRate / fftSize)
				if 1.4 < (firstFreq / thirdFreq) < 1.6
					peak = peaks[2]

			if peaks.length > 1 or maxPeaks is 1
				if not peak?
					peak = peaks[0]
		
				left = x: peak.x - 1, y: Math.log(fft.spectrum[peak.x - 1])
				peak = x: peak.x, y: Math.log(fft.spectrum[peak.x])
				right = x: peak.x + 1, y: Math.log(fft.spectrum[peak.x + 1])
		
				interp = (0.5 * ((left.y - right.y) / (left.y - (2 * peak.y) + right.y)) + peak.x)
				freq = interp * (sampleRate / fftSize)

				render freq

		else
			maxPeaks = 0
			maxPeakCount++
			#if maxPeakCount > 20
			#	display.clear()
		
		# render freq


	getPitch = (freq) ->
		minDiff = Infinity
		diff = Infinity
		for own key, val of frequencies
			if Math.abs(freq - val) < minDiff
				minDiff = Math.abs(freq - val)
				diff = freq - val
				note = key
		note


	getNeighbours = (note) ->
		lower = 'A0'
		higher = 'G#7'
		for own key, val of frequencies
			lower = key if frequencies[lower] < val < frequencies[note]
			higher = key if frequencies[higher] > val > frequencies[note]
		[lower, higher]


	removeLower = (el) ->
		el.setAttribute "class", "lower"
		setTimeout (-> el.parentNode.removeChild el), 500

	removeHigher = (el) ->
		el.setAttribute "class", "higher"
		setTimeout (-> el.parentNode.removeChild el), 500

	addLower = (el) ->
		el.setAttribute	"class", "lower"
		labels.appendChild el
		setTimeout (-> el.setAttribute "class", "current"), 100

	addHigher = (el) ->
		el.setAttribute	"class", "higher"
		labels.appendChild el
		setTimeout (-> el.setAttribute "class", "current"), 100

	render = (freq) ->
		
		note = getPitch freq
		[lower, higher] = getNeighbours note

		lowStep = (frequencies[note] - frequencies[lower]) / 5
		highStep = (frequencies[note] - frequencies[lower]) / 5

		prevLabels = (document.querySelectorAll ".labels .current") || document.createElement "div"

		nextLabels = document.createElement "div"
		for i in [0...5]
			span = document.createElement "span"
			span.innerHTML = precision (frequencies[note] + (i-2)*lowStep)
			nextLabels.appendChild span

		if frequencies[prevNote] < frequencies[note]
			removeLower i for own i in prevLabels
			addHigher nextLabels
		else if frequencies[prevNote] > frequencies[note]
			removeHigher i for own i in prevLabels
			addLower nextLabels


		elFreq.innerHTML = precision freq
		elFreq.classList.remove "inactive"


		needle.attr "opacity": 1


		low = frequencies[note] - 2*lowStep
		variation = (freq - frequencies[note]) / (frequencies[note] - low)

		needle.animate {transform: "r#{precision(variation*32)},350,350"}, 400, "<>"


		(document.querySelector ".debug-note").innerHTML = note
		(document.querySelector ".debug-frequency").innerHTML = freq


		activeNote = document.querySelector ".notes .active"
		activeNote.classList.remove "active" if activeNote

		activeNote = document.querySelector "#" + note.replace(/[0-9]+/, '').replace('#', '-sharp').toLowerCase()
		activeNote.classList.add "active" if activeNote

		prevNote = note

		clearTimeout fadeOutInterval
		setTimeout (-> fadeOutInfo()), 1000


	fadeOutInfo = () ->
		needle.attr "opacity": 0.3

		activeNote = document.querySelector ".notes .active"
		activeNote.classList.remove "active" if activeNote
		
		elFreq.classList.add "inactive"

	
	setInterval process, 100


error = (e) -> 
	console.log e
	console.log 'ARE YOU USING CHROME CANARY (23/09/2012) ON A MAC WITH "Web Audio Input" ENABLED IN chrome://flags?'


navigator.getUserMedia audio: true, success, error


