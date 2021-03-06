@IPCD @Swann
Feature: IPCD Swann Plug Driver Test

	These scenarios test the functionality of the IPCD Swann Plug driver.
	
	Background:
		Given the IPCD_Swann_Plug.driver has been initialized
	
	Scenario: Driver reports capabilities to platform.
    When a base:GetAttributes command is placed on the platform bus
    Then the driver should place a base:GetAttributesResponse message on the platform bus
	    And the message's base:caps attribute list should be ['base', 'dev', 'devadv', 'devpow', 'devconn', 'devota', 'swit', 'wifi']
	    And the message's dev:devtypehint attribute should be Switch
	    And the message's devadv:drivername attribute should be IPCDSwannPlug
	    And the message's devadv:driverversion attribute should be 1.0
	    And the message's devpow:source attribute should be LINE																							
	    And the message's devpow:linecapable attribute should be true	
	
	Scenario: Device Added
			When the device is added
	    When a base:GetAttributes command is placed on the platform bus
	    Then the driver should place a base:GetAttributesResponse message on the platform bus
			Then the driver should place a base:ValueChange message on the platform bus
				And the message's swit:state attribute should be OFF
	 			And the capability swit:statechanged should be recent
	 			And the capability devpow:sourcechanged should be recent
	 			And the capability devota:status should be IDLE
			Then the driver should schedule event callGPV in 500 milliseconds 
			Then the driver should send GetDeviceInfo command
	 		Then the driver variable KEY_PENDING_SWITCH should be null
			Then both busses should be empty				
			
	Scenario: Device removed
		  When the device is removed
		  Then protocol message count is 1	
		  Then the driver should send FactoryReset command
		
	Scenario Outline: Platform turns on switch via attribute change.
		When a base:SetAttributes command with the value of swit:state <request> is placed on the platform bus
		Then protocol message count is 1
		Then the driver should send SetParameterValues command
			And with parameter switch.state <command>		
		Then the driver variable KEY_PENDING_SWITCH should be <pending>

		Examples:
			| request | command |pending|
			| ON      |  ON     |recent  |
			| OFF     |  OFF    |recent  |
		
	Scenario Outline: Platform drops switch attribute change when pending.
		Given the time driver variable KEY_PENDING_SWITCH is <time> ms ago 
		When a base:SetAttributes command with the value of swit:state <request> is placed on the platform bus
		Then protocol bus should be empty

		Examples:
			| request | command |time|
			| ON      |  ON     |300    |
			| OFF     |  OFF    |300    |

Scenario Outline: Platform turns on switch via attribute when KEY_PENDING_SWITCH is old.
		Given the time driver variable KEY_PENDING_SWITCH is <pending> sec ago 
		When a base:SetAttributes command with the value of swit:state <request> is placed on the platform bus
		Then the driver should send SetParameterValues command
			And with parameter switch.state <command>
			
		Examples:
			| request | command |pending|
			| ON      |  ON     | 1    |
			| OFF     |  OFF    | 1    |	

Scenario: Platform turns on switch when KEY_PENDING_SWITCH not set.
		Given the driver variable KEY_PENDING_SWITCH is null 
		When a base:SetAttributes command with the value of swit:state ON is placed on the platform bus
		Then the driver should send SetParameterValues command
			And with parameter switch.state ON
			
	Scenario: Platform starts OTA
		Given the capability devota:status is IDLE
	 	When the capability method devota:FirmwareUpdate
	 	 	And with capability url is https://someserver.com/complex/path/file160728-morewords.bin
 			And with capability priority is URGENT
 			And send to driver
 		Then the driver should place a devota:FirmwareUpdateResponse message on the platform bus
		Then the driver should send Download command
			And with parameter url https://someserver.com/complex/path/file160728-morewords.bin	
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be INPROGRESS
			And the capability devota:lastFailReason should be ""
			And the capability devota:lastAttempt should be recent
			And the capability devota:progressPercent should be 0
			And the capability devota:targetVersion should be file160728-morewords
		Then the driver should schedule event DeviceOtaCheckTimeout in 1800 seconds

	Scenario Outline: Bad formatted URLs are rejected
			Given the capability devota:status is IDLE
	 	When the capability method devota:FirmwareUpdate
	 	 	And with capability url is 	<url>
 			And with capability priority is URGENT
 			And send to driver
 		Then the driver should place a devota:FirmwareUpdateResponse message on the platform bus
 			And the capability devota:status should be IDLE
		Then the protocol bus should be empty
		
	Examples:
	| url 																					|
	#No File
	|    https://someserver.com/    								|
	#Unexpected Format
	|    https://someserver.com/file.txt						|
	#No Protocol
	|   someserver.com/complex/path/file.bin      	|
	#No server
	|		https://filname.bin													|
	#No date in filename
	|		https://someserver.com/newversion.bin				|
	#No target version
	| 	https://someserver.com/.bin									|
	
	Scenario: OTA Rejected if OTA in progress
		Given the capability devota:status is INPROGRESS
			#Arbitrary time to confirm unchanged
			And the capability devota:lastAttempt is Wed Oct 12 00:00:00 EDT 2016
	 	When the capability method devota:FirmwareUpdate
	 	 	And with capability url is https://someserver.com/complex/path/file160728-morewords.bin
 			And with capability priority is URGENT
 			And send to driver
 		Then the driver should place a devota:FirmwareUpdateResponse message on the platform bus
 			And the capability devota:status should be INPROGRESS
 			And the capability devota:lastAttempt should be Wed Oct 12 00:00:00 EDT 2016
		Then the protocol bus should be empty	
		
	Scenario: Platform cancels OTA
		Given the capability devota:status is INPROGRESS
	 	When the capability method devota:FirmwareUpdateCancel
 			And send to driver
 		Then the driver should place a devota:FirmwareUpdateCancelResponse message on the platform bus
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be IDLE
			And the capability devota:lastFailReason should be Cancelled

		Scenario: Platform tries to cancel OTA with none in progress
			Given the capability devota:status is FAILED
		 	When the capability method devota:FirmwareUpdateCancel
	 			And send to driver
	 		Then the driver should place a devota:FirmwareUpdateCancelResponse message on the platform bus
				And the capability devota:status should be FAILED

	Scenario: OnDownloadComplete
		When the device response with event onDownloadComplete
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:progressPercent should be 50

	Scenario: OnDownloadFailed
		When the device response with event onDownloadFailed
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be FAILED
			And the capability devota:lastFailReason should be Download Failed

	Scenario: Ignore onUpgrade
		When the device response with event onUpdate
			And send to driver
		Then both busses should be empty
		
	Scenario: Ignore onBoot
		When the device response with event onBoot
			And send to driver
		Then both busses should be empty
		
	Scenario: Handle onConnect event
		When the device response with event onConnect
			And send to driver
		Then the driver should schedule event callGPV in 500 milliseconds 
		Then the driver should send GetDeviceInfo command

	Scenario Outline: Value Change Process and clear pending switch
		Given the driver variable KEY_PENDING_SWITCH is <before> 
		When the device sends event onValueChange	 
			And with parameter <parameter> <value>		
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability <namespace>:<attribute> should be <result>
		Then the driver variable KEY_PENDING_SWITCH should be <after>

		Examples:
			|   parameter    |  value  		| namespace | attribute | result 	| before | after |
			|   wifi.SSID    |  freeWiFi  | wifi      |  ssid     |	freeWiFi| NOW    | recent  |
			|   wifi.SSID    |  IRIS      | wifi      |  ssid     |	 IRIS   | null	 | null |
			|   switch.state |   ON       | swit      |  state    |   ON    | NOW		 | null |
			|   switch.state |   OFF      | swit      |  state    |  OFF    | NOW		 | null |
			|   switch.state |   ON       | swit      |  state    |   ON    | null   | null |
			|   switch.state |   OFF      | swit      |  state    |  OFF    | null   | null |

	Scenario: Handle GetParameterValuesResponse
		When the device sends response GetParameterValuesResponse	 
			And with parameter switch.state ON
			And with parameter wifi.SSID PennyIsAFreeloader		
			And with parameter wifi.RSSI -35		
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability swit:state should be ON
			And the capability wifi:ssid should be PennyIsAFreeloader
			And the capability wifi:rssi should be -35
			
	Scenario: Handle GetDeviceInfoResponse
		When the device sends response GetDeviceInfoResponse	 
			And with parameter fwver 1.0.160721-golden-wss-bi.443
			And with parameter connection persistent		
			And with parameter connectUrl wss://dev-bi.arcus.com//ipcd/1.0
			And with parameter actions  ["Report","Event"]
			And with parameter commands  ["GetDeviceInfo","GetParameterValues","SetParameterValues"]		
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:currentVersion should be 1.0.160721-golden-wss-bi.443

	Scenario: Handle a periodic report
		When the device sends report periodically
			And with parameter switch.state OFF
			And with parameter wifi.RSSI -35		
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability swit:state should be OFF
			And the capability wifi:rssi should be -35
			
	Scenario Outline: GetDeviceInfoResponse updates OTA Status
		Given the capability devota:status is <beforeState>
			And the capability devota:lastFailReason is <beforeReason>
			And the capability devota:progressPercent is <beforeProgress>
			And the capability devota:targetVersion is <targetVersion>
		When the device sends response GetDeviceInfoResponse
			And with parameter fwver <versionString>		
			And send to driver
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be <afterState>
			And the capability devota:lastFailReason should be <afterReason>
			And the capability devota:progressPercent should be <afterProgress>

		Examples:
			| beforeState | beforeReason | beforeProgress | targetVersion 									| versionString 								| afterState 	| afterReason | afterProgress |
#	Happy Path
			| INPROGRESS  |  ""          | 50				      |  ota.160721golden.bi.443.bin    |	1.0.160721-golden-wss-bi.443	| COMPLETED   | ""  				| 100 					|
# Fallback Image
			| INPROGRESS  |  ""          | 50      				|  ota.160721golden.bi.443.bin    |	1.0.160720p-golden-wss-bi.443 | FAILED			| Unexpected Version |   50   |
# Download Failed - Don't erase reason
			| FAILED  |  Download Failed | 0      				|  ota.160721golden.bi.443.bin    |	1.0.160720p-golden-wss-bi.443 | FAILED			| Download Failed    |    0   |
# Was Offline - success
			| FAILED  |  Offline | 50      				|  ota.160721golden.bi.443.bin    |	1.0.160721-golden-wss-bi.443 | COMPLETED			| ""    |    100   |
# No Date in Target Version Always Fails
			| INPROGRESS  |  ""          | 50      				|  ota.16072golden.bi.443.bin    |	1.0.160720p-golden-wss-bi.443 | FAILED			| No Date in Target Version |   50   |

	Scenario: Device offline fails OTA
		Given the capability devota:status is INPROGRESS
		When the device is disconnected
		Then the driver should schedule event offlineCheck in 30 seconds 


	Scenario: ScheduleCheck fails if still offline
		Given the capability devota:status is INPROGRESS
		When event offlineCheck triggers
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be FAILED
			And the capability devota:lastFailReason should be Offline
				
	Scenario Outline: Device offline doesn't do anything when not doing OTA
		Given the capability devota:status is <beforeState>
			And the capability devota:lastFailReason is <beforeReason>
		When the device is disconnected
		Then the driver should place a base:ValueChange message on the platform bus
			And the capability devota:status should be <afterState>
			And the capability devota:lastFailReason should be <afterReason>

		Examples:		
			| beforeState | beforeReason 		| afterState 	| afterReason | 
			| IDLE        |   ""         		|   IDLE       |  ""      |
			| FAILED		  |Download Failed  |   FAILED     |   Download Failed   |
			| COMPLETED   |    ""        		|   COMPLETED  |  ""        |
			