class_name SampleDecks
extends RefCounted
## Built-in decks so judges can play instantly, even if the server is asleep.
## Generated from backend/decks by tools/export_samples.py. Don't edit by hand.

const DECKS := [
	{
		"id": "photosynthesis",
		"title": "The Chlorophyll Crypt",
		"subject": "Photosynthesis",
		"concepts": [
			{
				"id": "c1",
				"name": "The Big Picture",
				"summary": "Plants turn CO2 and water into glucose using light, releasing oxygen.",
				"difficulty": 1,
				"questions": [
					{
						"id": "c1q1",
						"prompt": "Which gas is released as a by-product of photosynthesis?",
						"choices": [
							"Nitrogen",
							"Carbon dioxide",
							"Hydrogen",
							"Oxygen"
						],
						"answer_index": 3,
						"explanation": "Plants take in CO2 and give out O2.",
						"source_quote": "Oxygen is released as a by-product.",
						"grounded": true
					},
					{
						"id": "c1q2",
						"prompt": "What are the raw materials plants use to make glucose?",
						"choices": [
							"Nitrogen and carbon dioxide",
							"Glucose and oxygen",
							"Carbon dioxide and water",
							"Oxygen and water"
						],
						"answer_index": 2,
						"explanation": "CO2 and H2O go in; glucose and O2 come out.",
						"source_quote": "Photosynthesis is the process by which green plants use light energy to make glucose from carbon dioxide and water.",
						"grounded": true
					},
					{
						"id": "c1q3",
						"prompt": "Where in the leaf cell does photosynthesis mainly happen?",
						"choices": [
							"Mitochondria",
							"Cell wall",
							"Nucleus",
							"Chloroplasts"
						],
						"answer_index": 3,
						"explanation": "Chloroplasts hold the chlorophyll that captures light.",
						"source_quote": "Photosynthesis takes place mainly in the leaves, inside organelles called chloroplasts.",
						"grounded": true
					}
				]
			},
			{
				"id": "c2",
				"name": "Chlorophyll & Chloroplasts",
				"summary": "The green pigment and the structures that hold it.",
				"difficulty": 1,
				"questions": [
					{
						"id": "c2q1",
						"prompt": "Why do leaves look green?",
						"choices": [
							"Chlorophyll absorbs green light",
							"Stomata are green",
							"Chlorophyll reflects green light",
							"Glucose is green"
						],
						"answer_index": 2,
						"explanation": "We see the colour that is reflected, not absorbed.",
						"source_quote": "Chlorophyll absorbs mostly red and blue light and reflects green light, which is why leaves look green.",
						"grounded": true
					},
					{
						"id": "c2q2",
						"prompt": "What are the stacked membrane discs inside a chloroplast called?",
						"choices": [
							"Stroma",
							"Stomata",
							"Ribosomes",
							"Thylakoids"
						],
						"answer_index": 3,
						"explanation": "Thylakoids hold the chlorophyll; stroma is the fluid around them.",
						"source_quote": "Inside the chloroplast, stacks of membrane discs called thylakoids hold the chlorophyll.",
						"grounded": true
					},
					{
						"id": "c2q3",
						"prompt": "What is the fluid around the thylakoids called?",
						"choices": [
							"Cytoplasm",
							"Guard fluid",
							"Chlorophyll",
							"Stroma"
						],
						"answer_index": 3,
						"explanation": "The stroma is where the Calvin cycle happens.",
						"source_quote": "The fluid around the thylakoids is called the stroma.",
						"grounded": true
					}
				]
			},
			{
				"id": "c3",
				"name": "Two Stages",
				"summary": "Light-dependent reactions make ATP/NADPH; the Calvin cycle uses them to fix CO2.",
				"difficulty": 3,
				"questions": [
					{
						"id": "c3q1",
						"prompt": "Where do the light-dependent reactions take place?",
						"choices": [
							"Mitochondria",
							"Stroma",
							"Thylakoid membranes",
							"Stomata"
						],
						"answer_index": 2,
						"explanation": "Light hits chlorophyll in the thylakoid membranes.",
						"source_quote": "The light-dependent reactions take place in the thylakoid membranes.",
						"grounded": true
					},
					{
						"id": "c3q2",
						"prompt": "The Calvin cycle uses which products of the light-dependent reactions?",
						"choices": [
							"Oxygen and water",
							"Chlorophyll and RuBisCO",
							"ATP and NADPH",
							"Glucose and oxygen"
						],
						"answer_index": 2,
						"explanation": "Stage 1 makes the energy carriers; stage 2 spends them.",
						"source_quote": "The Calvin cycle uses ATP and NADPH to fix carbon dioxide into glucose.",
						"grounded": true
					},
					{
						"id": "c3q3",
						"prompt": "In which stage is water split?",
						"choices": [
							"Light-dependent reactions",
							"Both stages",
							"Calvin cycle",
							"Neither stage"
						],
						"answer_index": 0,
						"explanation": "Splitting water is where the released oxygen comes from.",
						"source_quote": "In these reactions, water is split and oxygen is released.",
						"grounded": true
					},
					{
						"id": "c3q4",
						"prompt": "Which enzyme captures carbon dioxide in the Calvin cycle?",
						"choices": [
							"ATP synthase",
							"Chlorophyll",
							"RuBisCO",
							"Amylase"
						],
						"answer_index": 2,
						"explanation": "RuBisCO grabs CO2 so it can be built into sugar.",
						"source_quote": "The enzyme RuBisCO captures carbon dioxide in the Calvin cycle.",
						"grounded": true
					}
				]
			},
			{
				"id": "c4",
				"name": "Limiting Factors",
				"summary": "Light, CO2 and temperature control how fast photosynthesis runs.",
				"difficulty": 2,
				"questions": [
					{
						"id": "c4q1",
						"prompt": "Why does a very high temperature reduce the rate of photosynthesis?",
						"choices": [
							"Stomata absorb too much light",
							"Chlorophyll turns red",
							"Water stops being split forever",
							"Enzymes start to denature"
						],
						"answer_index": 3,
						"explanation": "Enzymes like RuBisCO lose their shape when too hot.",
						"source_quote": "Very high temperatures reduce the rate because enzymes start to denature.",
						"grounded": true
					},
					{
						"id": "c4q2",
						"prompt": "You keep increasing light intensity. What happens to the rate?",
						"choices": [
							"It does not change at all",
							"It drops immediately",
							"It rises forever",
							"It rises until another factor becomes limiting"
						],
						"answer_index": 3,
						"explanation": "After a point, CO2 or temperature holds it back.",
						"source_quote": "Increasing light intensity raises the rate only until another factor becomes limiting.",
						"grounded": true
					},
					{
						"id": "c4q3",
						"prompt": "How does carbon dioxide get into the leaf?",
						"choices": [
							"Through the stroma",
							"Through the roots",
							"Through stomata",
							"Through chloroplasts directly"
						],
						"answer_index": 2,
						"explanation": "Stomata are tiny pores, opened and closed by guard cells.",
						"source_quote": "Carbon dioxide enters the leaf through tiny pores called stomata.",
						"grounded": true
					}
				]
			}
		],
		"dropped_ungrounded": 0
	},
	{
		"id": "stacks-queues",
		"title": "The LIFO Labyrinth",
		"subject": "Stacks and Queues",
		"concepts": [
			{
				"id": "c1",
				"name": "Stack Basics (LIFO)",
				"summary": "A stack adds and removes from the same end: last in, first out.",
				"difficulty": 1,
				"questions": [
					{
						"id": "c1q1",
						"prompt": "Which principle does a stack follow?",
						"choices": [
							"Highest priority first",
							"First In, First Out",
							"Random access",
							"Last In, First Out"
						],
						"answer_index": 3,
						"explanation": "A stack removes the most recently added element first, so it is LIFO.",
						"source_quote": "A stack is a linear data structure that follows the Last In, First Out (LIFO) principle.",
						"grounded": true
					},
					{
						"id": "c1q2",
						"prompt": "What does the peek operation do on a stack?",
						"choices": [
							"Adds an element to the top",
							"Removes the bottom element",
							"Returns the top element without removing it",
							"Removes the top element"
						],
						"answer_index": 2,
						"explanation": "Peek only looks at the top. Pop is the one that removes it.",
						"source_quote": "The peek operation returns the top element without removing it.",
						"grounded": true
					},
					{
						"id": "c1q3",
						"prompt": "You pop from an empty stack. What happens?",
						"choices": [
							"Stack overflow",
							"The stack becomes a queue",
							"It returns the bottom element",
							"Stack underflow"
						],
						"answer_index": 3,
						"explanation": "Removing from nothing is an underflow. Overflow is pushing onto a full stack.",
						"source_quote": "Trying to pop from an empty stack causes a stack underflow.",
						"grounded": true
					}
				]
			},
			{
				"id": "c2",
				"name": "Queue Basics (FIFO)",
				"summary": "A queue adds at the rear and removes from the front: first in, first out.",
				"difficulty": 1,
				"questions": [
					{
						"id": "c2q1",
						"prompt": "Where does enqueue add a new element?",
						"choices": [
							"At the front",
							"In the middle",
							"At the rear",
							"At the top"
						],
						"answer_index": 2,
						"explanation": "New elements join the back of the line, like people in a queue.",
						"source_quote": "Enqueue adds an element at the rear of the queue.",
						"grounded": true
					},
					{
						"id": "c2q2",
						"prompt": "Which element leaves a queue first?",
						"choices": [
							"The one added last",
							"The one with highest priority",
							"A random one",
							"The one added first"
						],
						"answer_index": 3,
						"explanation": "Queues are FIFO, so the oldest element is removed first.",
						"source_quote": "The element added first is the first one to be removed.",
						"grounded": true
					},
					{
						"id": "c2q3",
						"prompt": "Dequeue removes an element from which end?",
						"choices": [
							"The rear",
							"The top",
							"Both ends",
							"The front"
						],
						"answer_index": 3,
						"explanation": "Dequeue takes from the front, enqueue adds at the rear.",
						"source_quote": "Dequeue removes an element from the front of the queue.",
						"grounded": true
					}
				]
			},
			{
				"id": "c3",
				"name": "Implementation & Complexity",
				"summary": "How stacks and queues are built and why their core operations are O(1).",
				"difficulty": 2,
				"questions": [
					{
						"id": "c3q1",
						"prompt": "What is the time complexity of push and dequeue in a well-implemented stack or queue?",
						"choices": [
							"O(log n)",
							"O(n)",
							"O(1)",
							"O(n log n)"
						],
						"answer_index": 2,
						"explanation": "They only touch one end, so no loop over the elements is needed.",
						"source_quote": "In a well-implemented stack or queue, push, pop, enqueue and dequeue all run in O(1) time.",
						"grounded": true
					},
					{
						"id": "c3q2",
						"prompt": "Why does a simple array-based queue waste space?",
						"choices": [
							"Arrays cannot store integers",
							"The rear never moves",
							"The front moves forward after every dequeue",
							"Enqueue copies the whole array"
						],
						"answer_index": 2,
						"explanation": "Slots before the front are left empty and never reused.",
						"source_quote": "A simple array-based queue wastes space because the front moves forward after every dequeue.",
						"grounded": true
					},
					{
						"id": "c3q3",
						"prompt": "A linked-list queue keeps pointers to which nodes?",
						"choices": [
							"Both the head and the tail",
							"Only the tail",
							"Only the head",
							"Every middle node"
						],
						"answer_index": 0,
						"explanation": "Head for dequeue, tail for enqueue, so both stay O(1).",
						"source_quote": "A queue implemented with a linked list keeps pointers to both the head and the tail.",
						"grounded": true
					}
				]
			},
			{
				"id": "c4",
				"name": "Circular Queues",
				"summary": "Reusing freed array slots by wrapping indices around with modulo.",
				"difficulty": 3,
				"questions": [
					{
						"id": "c4q1",
						"prompt": "What problem does a circular queue solve?",
						"choices": [
							"Slow O(n) pop",
							"Priority ordering",
							"Wasted space in an array-based queue",
							"Stack underflow"
						],
						"answer_index": 2,
						"explanation": "By wrapping around, it reuses the empty slots before the front.",
						"source_quote": "A circular queue solves this by wrapping the rear index back to the start of the array using the modulo operator.",
						"grounded": true
					},
					{
						"id": "c4q2",
						"prompt": "Which operator lets the rear index wrap back to the start of the array?",
						"choices": [
							"Bitwise OR (|)",
							"Division (/)",
							"Exponent (^)",
							"Modulo (%)"
						],
						"answer_index": 3,
						"explanation": "rear = (rear + 1) % size brings the index back to 0 after the last slot.",
						"source_quote": "A circular queue solves this by wrapping the rear index back to the start of the array using the modulo operator.",
						"grounded": true
					}
				]
			},
			{
				"id": "c5",
				"name": "Real Uses & Variants",
				"summary": "Call stacks, BFS/DFS, deques and priority queues.",
				"difficulty": 3,
				"questions": [
					{
						"id": "c5q1",
						"prompt": "Breadth-first search visits nodes level by level using which structure?",
						"choices": [
							"A hash map",
							"A priority queue",
							"A stack",
							"A queue"
						],
						"answer_index": 3,
						"explanation": "FIFO order makes BFS finish one level before moving to the next.",
						"source_quote": "Breadth-first search uses a queue to visit nodes level by level.",
						"grounded": true
					},
					{
						"id": "c5q2",
						"prompt": "What does the call stack store?",
						"choices": [
							"Only global variables",
							"Every variable ever declared",
							"A frame for every active function call",
							"The program's source code"
						],
						"answer_index": 2,
						"explanation": "Each call pushes a frame; returning pops it.",
						"source_quote": "The call stack stores a frame for every active function call.",
						"grounded": true
					},
					{
						"id": "c5q3",
						"prompt": "How is a priority queue different from a normal queue?",
						"choices": [
							"It allows insertion at both ends",
							"It has no remove operation",
							"It removes the newest element first",
							"It removes the highest-priority element, not the oldest"
						],
						"answer_index": 3,
						"explanation": "Order depends on priority, not on arrival time.",
						"source_quote": "A priority queue removes the element with the highest priority first, not the oldest one.",
						"grounded": true
					},
					{
						"id": "c5q4",
						"prompt": "Which structure allows insertion and deletion at both ends?",
						"choices": [
							"Deque",
							"Stack",
							"Circular stack",
							"Priority queue"
						],
						"answer_index": 0,
						"explanation": "Deque = double-ended queue.",
						"source_quote": "A deque, or double-ended queue, allows insertion and deletion at both ends.",
						"grounded": true
					}
				]
			}
		],
		"dropped_ungrounded": 0
	}
]
