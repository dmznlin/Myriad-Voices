{*******************************************************************************
  作者: dmzn@163.com 2024-12-17
  描述: 全局常量、变量定义
*******************************************************************************}
unit USysConst;

interface

uses ULibFun;

const
  cTag_Ok = 99;

var
  gPath: string;
  //系统所在路径
  gApp: TApplicationHelper.TAppParam;
  //全局配置参数

resourcestring
  {*字符串资源*}
  sFlag_Yes = 'Y';
  sFlag_No  = 'N';
  sHint     = '提示';
  sParamTag = #9;

  //机器锁文件
  sFileKey  = 'Config.lck';
  //模板文件
  sFileModal = 'modals.json';

implementation

end.
