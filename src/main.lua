-- @Project   : Air724UG-Message-Forwarding-Via-Email
-- @Author    : Dancying
-- @Time      : 2024/6/1
-- @Email     : dancying2023@163.com
-- @FileName  : main.lua
-- @Software  : Sublime Text 4


-- Project Info
PROJECT = "Air724UG-Message-Forwarding-Via-Email"
VERSION = "1.0.1"


-- Import Packages
require "audio"
require "cc"
require "common"
require "netLed"
require "ril"
require "sms"
require "socket4G"
require "sys"


-- Email Settings
local email_subject         = ""                            -- 邮件标题，此处留空
local email_from            = "Sender_Email@163.com"        -- 发件人邮箱地址
local email_to              = "Receiver_Email@163.com"      -- 收件人邮箱地址
local email_content         = ""                            -- 邮件正文，此处留空
local smtp_host             = "smtp.163.com"                -- SMTP 服务器地址
local smtp_port             = "465"                         -- SMTP 服务器端口
local smtp_user             = "Sender_Email@163.com"        -- SMTP 登录的邮箱账户
local smtp_passwd           = "AAAABBBBCCCCDDDD"            -- SMTP 登录的账户密码


-- Preset Functions
function emailSendingProcessing(subject,content)
    -- body
    local socket_client = nil
    local socket_msg = {
        "HELO Air724UG",
        "AUTH LOGIN",
        crypto.base64_encode(smtp_user,string.len(smtp_user)),
        crypto.base64_encode(smtp_passwd,string.len(smtp_passwd)),
        "MAIL FROM: <"..email_from..">",
        "RCPT TO: <"..email_to..">",
        "DATA",
        "Subject: =?utf-8?B?"..crypto.base64_encode(subject,string.len(subject)).."?=",
        "From: <"..email_from..">",
        "To: <"..email_to..">",
        "Content-Type: text/plain; charset=\"utf-8\"",
        "Content-Transfer-Encoding: base64",
        "MIME-Version: 1.0",
        "",
        crypto.base64_encode(content,string.len(content)),
        ".",
        "QUIT",
    }

    if smtp_port == "25" then socket_client = socket4G.tcp() else socket_client = socket4G.tcp(true) end
    socket_client:connect(smtp_host,smtp_port)
    log.info("emailSendingProcessing","Socket Connected")
    for i,v in ipairs(socket_msg) do
        socket_client:send(v,15000)
        socket_client:send("\r\n",15000)
        log.info("emailSendingProcessing","Socket Send -> "..v)
    end
    socket_client:close()
    log.info("emailSendingProcessing","Socket Disconnected")
end

function callMessageProcessing()
    -- body
    local call_num = nil
    local call_time = nil

    local function callNewIncomingProcessing(num)
        -- body
        if not call_num then
            call_num = num
            log.info("callNewIncomingProcessing","Call From -> "..num)

            sys.taskInit(function ()
                -- body
                sys.waitUntil("CALL_DISCONNECTED",15000)
                if cc.getState(num) == 4 then cc.accept(num) end
            end)
        end
    end

    local function callConnectedProcessing(num)
        -- body
        call_num,call_time = num,os.time()
        log.info("callConnectedProcessing","Call Connected -> "..num)
        audio.play(9,"TTS","您好，本号码为无人值守状态，请使用短信留言",7,nil,true,2280)

        sys.taskInit(function ()
            -- body
            sys.waitUntil("CALL_DISCONNECTED",30000)
            if cc.getState(num) == 0 then
                cc.hangUp(num)
                log.info("callConnectedProcessing","Call Hang Up -> "..num)
            end
        end)
    end

    local function callDisconnectedProcessing()
        -- body
        if call_time then
            call_time = os.time() - call_time
            log.info("callDisconnectedProcessing","Call Ended -> "..call_num)
            audio.stop()

            local subject = "Call From 【"..call_num.."】"
            local content = "来自 【"..call_num.."】 的通话已结束，通话时间为 "..call_time.." 秒。"
            sys.taskInit(emailSendingProcessing,subject,content)

            call_num,call_time = nil,nil
        elseif call_num then
            log.info("callDisconnectedProcessing","Call Ended -> "..call_num)
            call_num = nil
        end
    end

    sys.subscribe("CALL_INCOMING",callNewIncomingProcessing)
    sys.subscribe("CALL_CONNECTED",callConnectedProcessing)
    sys.subscribe("CALL_DISCONNECTED",callDisconnectedProcessing)
end

function smsMessageProcessing()
    -- body
    local function smsNewMessageProcessing(num,data,datetime)
        -- body
        local data = common.gb2312ToUtf8(data)
        local datetime = "20"..datetime
        log.info("smsNewMessageProcessing","New SMS From : "..num)
        log.info("smsNewMessageProcessing","SMS Content : "..data)
        log.info("smsNewMessageProcessing","SMS Date & Time : "..datetime)

        local subject = "SMS From 【"..num.."】"
        local content = data.."\n\n"..datetime
        sys.taskInit(emailSendingProcessing,subject,content)
    end

    sms.setNewSmsCb(smsNewMessageProcessing)
end

function advancedSystemSettings()
    -- body
    pmd.ldoset(10,pmd.LDO_VLCD)
    netLed.setup(true,pio.P0_1,pio.P0_4)
    netLed.updateBlinkTime("SIMERR",0xFFFF,0)       -- SIM 卡异常，网络指示灯常亮
    netLed.updateBlinkTime("GPRS",0,0xFFFF)         -- GPRS 状态， 网络指示灯常灭

    ril.request("AT+RNDISCALL=0,1")
    log.info("advancedSystemSettings","Disable RNDIS")
end


-- Enable Features
smsMessageProcessing()
callMessageProcessing()
advancedSystemSettings()


-- Run Project
sys.init(0,0)
sys.run()

