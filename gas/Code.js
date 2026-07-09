/**
 * CompShare：每 5 天，对所有 Stopped 实例：无卡启动 → 再关机
 * 配置与 test_compshare.py 对齐：Region=cn-wlcb, base=api.compshare.cn
 */

var BASE_URL = 'https://api.compshare.cn';
var REGION = 'cn-wlcb';

/** 首次：写入密钥到脚本属性（与 test_compshare.py 一致） */
function setupSecrets() {
  PropertiesService.getScriptProperties().setProperties({
    PUBLIC_KEY: '4eZCa5hXL3RF9WLEaD4ZdvIrT1OSoQwUJ',
    PRIVATE_KEY: 'AA8Z5lfwhFR1fqF9PRlssWANnFgNfVQRzBb57grVcKmK',
  });
  Logger.log('密钥已保存');
}

/** 安装每 5 天触发（上海时区凌晨 3 点） */
function installTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'runCycle') {
      ScriptApp.deleteTrigger(t);
    }
  });

  ScriptApp.newTrigger('runCycle')
    .timeBased()
    .everyDays(5)
    .atHour(3)
    .create();

  Logger.log('已安装每 5 天触发器');
}

/** 仅测列表，不开关机 */
function testList() {
  var creds = getCreds_();
  var instances = listAllInstances_(creds.publicKey, creds.privateKey);
  Logger.log('总数: ' + instances.length);
  instances.forEach(function (inst) {
    Logger.log(
      JSON.stringify({
        UHostId: inst.UHostId,
        Name: inst.Name,
        State: inst.State,
        Zone: inst.Zone,
        SupportWithoutGpuStart: inst.SupportWithoutGpuStart,
      })
    );
  });
  return instances.length;
}

/**
 * 冒烟测试：只对 TARGET 关机实例做 无卡开→关（避免批量动全部机器）
 * TARGET 默认与 test_compshare.py 一致
 */
function testOneCycle() {
  var TARGET_ID = 'uhost-1mafdpxctojn';
  var creds = getCreds_();
  var instances = listAllInstances_(creds.publicKey, creds.privateKey);
  var target = null;
  for (var i = 0; i < instances.length; i++) {
    if (instances[i].UHostId === TARGET_ID) {
      target = instances[i];
      break;
    }
  }
  if (!target) {
    throw new Error('未找到实例 ' + TARGET_ID);
  }
  Logger.log('目标: ' + JSON.stringify({
    UHostId: target.UHostId,
    State: target.State,
    Zone: target.Zone,
  }));

  if (target.State === 'Running') {
    Logger.log('当前 Running，先关机再测无卡开→关');
    invoke_(creds.publicKey, creds.privateKey, {
      Action: 'StopCompShareInstance',
      Region: REGION,
      Zone: target.Zone,
      UHostId: target.UHostId,
    });
    waitStateByList_(creds.publicKey, creds.privateKey, target.UHostId, ['Stopped'], 180);
  } else if (target.State !== 'Stopped') {
    waitStateByList_(creds.publicKey, creds.privateKey, target.UHostId, ['Running', 'Stopped'], 180);
    return testOneCycle();
  }

  Logger.log('无卡启动...');
  invoke_(creds.publicKey, creds.privateKey, {
    Action: 'StartCompShareInstance',
    Region: REGION,
    Zone: target.Zone,
    UHostId: target.UHostId,
    WithoutGpuSpec: 'A',
  });
  waitStateByList_(creds.publicKey, creds.privateKey, target.UHostId, ['Running'], 180);
  Logger.log('已 Running，关机...');
  invoke_(creds.publicKey, creds.privateKey, {
    Action: 'StopCompShareInstance',
    Region: REGION,
    Zone: target.Zone,
    UHostId: target.UHostId,
  });
  waitStateByList_(creds.publicKey, creds.privateKey, target.UHostId, ['Stopped'], 180);
  Logger.log('testOneCycle 完成');
  return 'ok';
}

/** 正式周期：所有已关机实例 无卡开 → 关 */
function runCycle() {
  var creds = getCreds_();
  var instances = listAllInstances_(creds.publicKey, creds.privateKey);
  var stopped = instances.filter(function (x) {
    return x.State === 'Stopped';
  });

  Logger.log('总实例: ' + instances.length + '，已关机: ' + stopped.length);
  if (!stopped.length) {
    Logger.log('没有需要处理的关机实例');
    return;
  }

  stopped.forEach(function (inst) {
    Logger.log('无卡启动: ' + inst.UHostId + ' zone=' + inst.Zone);
    invoke_(creds.publicKey, creds.privateKey, {
      Action: 'StartCompShareInstance',
      Region: REGION,
      Zone: inst.Zone,
      UHostId: inst.UHostId,
      WithoutGpuSpec: 'A',
    });
  });

  stopped.forEach(function (inst) {
    waitStateByList_(creds.publicKey, creds.privateKey, inst.UHostId, ['Running'], 180);
    Logger.log('已启动: ' + inst.UHostId);
  });

  stopped.forEach(function (inst) {
    Logger.log('关机: ' + inst.UHostId);
    invoke_(creds.publicKey, creds.privateKey, {
      Action: 'StopCompShareInstance',
      Region: REGION,
      Zone: inst.Zone,
      UHostId: inst.UHostId,
    });
  });

  stopped.forEach(function (inst) {
    waitStateByList_(creds.publicKey, creds.privateKey, inst.UHostId, ['Stopped'], 180);
    Logger.log('已关机: ' + inst.UHostId);
  });

  Logger.log('本轮完成');
}

// ---------------- helpers ----------------

function getCreds_() {
  var props = PropertiesService.getScriptProperties();
  var publicKey = props.getProperty('PUBLIC_KEY');
  var privateKey = props.getProperty('PRIVATE_KEY');
  if (!publicKey || !privateKey) {
    setupSecrets();
    publicKey = props.getProperty('PUBLIC_KEY');
    privateKey = props.getProperty('PRIVATE_KEY');
  }
  if (!publicKey || !privateKey) {
    throw new Error('请先运行 setupSecrets 配置密钥');
  }
  return { publicKey: publicKey, privateKey: privateKey };
}

function listAllInstances_(publicKey, privateKey) {
  var offset = 0;
  var limit = 100;
  var all = [];
  while (true) {
    var resp = invoke_(publicKey, privateKey, {
      Action: 'DescribeCompShareInstance',
      Region: REGION,
      Limit: limit,
      Offset: offset,
    });
    var set = resp.UHostSet || [];
    all = all.concat(set);
    if (set.length < limit) break;
    offset += limit;
  }
  return all;
}

function waitStateByList_(publicKey, privateKey, uhostId, targets, timeoutSec) {
  var start = Date.now();
  while ((Date.now() - start) / 1000 < timeoutSec) {
    var all = listAllInstances_(publicKey, privateKey);
    var hit = null;
    for (var i = 0; i < all.length; i++) {
      if (all[i].UHostId === uhostId) {
        hit = all[i];
        break;
      }
    }
    var state = hit ? hit.State : null;
    Logger.log(uhostId + ' 当前状态: ' + state);
    if (targets.indexOf(state) >= 0) return hit;
    Utilities.sleep(5000);
  }
  throw new Error('等待状态超时: ' + uhostId + ' -> ' + targets.join('/'));
}

function invoke_(publicKey, privateKey, params) {
  var body = {};
  Object.keys(params).forEach(function (k) {
    body[k] = params[k];
  });
  body.PublicKey = publicKey;
  body.Signature = sign_(body, privateKey);

  var res = UrlFetchApp.fetch(BASE_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(body),
    muteHttpExceptions: true,
  });

  var text = res.getContentText();
  var code = res.getResponseCode();
  if (code < 200 || code >= 300) {
    throw new Error('HTTP ' + code + ': ' + text);
  }

  var data = JSON.parse(text);
  if (data.RetCode !== 0) {
    throw new Error(
      (data.Action || '') + ' RetCode=' + data.RetCode + ' ' + (data.Message || text)
    );
  }
  return data;
}

function sign_(params, privateKey) {
  var keys = Object.keys(params)
    .filter(function (k) {
      return params[k] !== null && params[k] !== undefined;
    })
    .sort();

  var raw = '';
  keys.forEach(function (k) {
    var v = params[k];
    if (typeof v === 'boolean') v = v ? 'true' : 'false';
    raw += k + String(v);
  });
  raw += privateKey;
  return sha1Hex_(raw);
}

function sha1Hex_(str) {
  var bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_1,
    str,
    Utilities.Charset.UTF_8
  );
  return bytes
    .map(function (b) {
      var v = b < 0 ? b + 256 : b;
      return ('0' + v.toString(16)).slice(-2);
    })
    .join('');
}
