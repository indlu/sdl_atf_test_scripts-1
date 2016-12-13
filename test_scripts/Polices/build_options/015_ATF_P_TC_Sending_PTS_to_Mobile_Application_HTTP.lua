---------------------------------------------------------------------------------------------
-- Requirements summary:
-- [PolicyTableUpdate] Sending PTS to mobile application
--
-- Description:
-- SDL must send PTS snapshot as a binary data via OnSystemRequest mobile API
-- from the system to backend. The "url" PTS will be forwarded to and "timeout"
-- must be taken from the Local Policy Table
-- 1. Used preconditions
-- SDL is built with "-DEXTENDED_POLICY: HTTP" flag
-- Application is registered.
-- PTU is requested.
-- SDL->HMI: SDL.OnStatusUpdate(UPDATE_NEEDED)
-- SDL->HMI:SDL.PolicyUpdate(file, timeout, retry[])
-- HMI -> SDL: SDL.GetURLs (<service>)
-- 2. Performed steps
-- HMI->SDL:BasicCommunication.OnSystemRequest ('url', requestType:HTTP, appID)
--
-- Expected result:
-- SDL->app: OnSystemRequest ('url', requestType:HTTP, fileType="JSON", appID)
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local testCasesForPolicyTableSnapshot = require('user_modules/shared_testcases/testCasesForPolicyTableSnapshot')

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()
--TODO: Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_Sending_PTS_to_mobile_application()
  local is_test_fail = false
  local endpoints = {}

  for i = 1, #testCasesForPolicyTableSnapshot.pts_endpoints do
    if (testCasesForPolicyTableSnapshot.pts_endpoints[i].service == "0x07") then
      endpoints[#endpoints + 1] = { url = testCasesForPolicyTableSnapshot.pts_endpoints[i].value, appID = nil}
    end

    if (testCasesForPolicyTableSnapshot.pts_endpoints[i].service == "app1") then
      endpoints[#endpoints + 1] = { url = testCasesForPolicyTableSnapshot.pts_endpoints[i].value, appID = testCasesForPolicyTableSnapshot.pts_endpoints[i].appID}
    end
  end

  local RequestId_GetUrls = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })

  EXPECT_HMIRESPONSE(RequestId_GetUrls,{result = {code = 0, method = "SDL.GetURLS", urls = endpoints} } )
  :Do(function(_,data)
      local app_urls = {}
      for i = 1, #data.result.urls do
        if(data.result.urls[i].appID == self.applications[config.application1.registerAppInterfaceParams.appName]) then
          app_urls = data.result.urls[i]
        else
          app_urls = endpoints[1]
          commonFunctions:printError("endpoints for application doesn't exist!")
          is_test_fail = true
        end
      end

      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",{
          requestType = "HTTP",
          fileName = "PolicyTableUpdate",
          url = app_urls.url,
          appID = app_urls.appID })

      EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "HTTP", fileType = "JSON", url = {app_urls.url}})
    end)

  if(is_test_fail == true) then
    self:FailTestCase("Test is FAILED. See prints.")
  end
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Stop_SDL()
  StopSDL()
end

return Test
