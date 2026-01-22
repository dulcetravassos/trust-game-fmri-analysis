last changed: 04.01.2023 by ines almeida
changes performed: 
1. PRT filename changed to sub-ID_ses-ID_task-name_run-ID.prt, to match BIDS and BV PRT formats
2. within file, changes to match BV generated PRT:
«The brainvoyagertools is a user-developed Python module which is intended to read PRTs and SDMs created in BrainVoyager. PRTs created in BrainVoyager follow a specifc format, e.g. 
Name of Condition
Number of events in condition
EventOnset /space EventOffset
Color of Condition 
I assume you have created the PRTs externally since there are additional empty lines between the header and the first Condition Definition and also between the last "EventOnset /space EventOffset" and "Color:".
BrainVoyager tolerates these differences in the format, but not the user-developed brainvoyagertools.» (judith eck, july 2022)
3. within file: added incongruent conditions, as they were lacking compared to the incongruent protocols (these included both congruent and incongruent conditions)

created: 23.10.2020 by ines almeida
location: [shared DRIVE]\TG\3DATA\STUDY2_maintasks\S2_source\protocols-task-trustgame\task-trustgame-congruent-trustee-eyegaze

folder includes:
BrainVoyager protocols for Study 2 - trust game task
>>part: congruent: runs 1 to 4
>> included: participants:
N=20
sub-tg02
sub-tg03
sub-tg04
sub-tg06
sub-tg07
sub-tg08
sub-tg09
sub-tg011
sub-tg012
sub-tg013
sub-tg014
sub-tg015
sub-tg016
sub-tg017
sub-tg018
sub-tg019
sub-tg020
sub-tg021
sub-tg022
sub-tg023

>> excluded: participants:
N=3
sub-tg01
sub-tg05
sub-tg010
