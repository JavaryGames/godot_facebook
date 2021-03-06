#include "godotfacebook.h"
#import "app_delegate.h"

#import <Foundation/Foundation.h>

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKCoreKit/FBSDKAppEvents.h>
#import <FBSDKCoreKit/FBSDKAccessToken.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>
#import <Bolts/Bolts.h>

NSDictionary *convertFromDictionary(const Dictionary& dict)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    for(int i=0; i<dict.size(); i++) {
        Variant key = dict.get_key_at_index(i); 
        Variant val = dict.get_value_at_index(i);
        if(key.get_type() == Variant::STRING) {
            NSString *strKey = [NSString stringWithUTF8String:((String)key).utf8().get_data()];
            if(val.get_type() == Variant::INT) {
                int i = (int)val;
                result[strKey] = @(i);
            } else if(val.get_type() == Variant::REAL) {
                double d = (double)val;
                result[strKey] = @(d);
            } else if(val.get_type() == Variant::STRING) {
                NSString *s = [NSString stringWithUTF8String:((String)val).utf8().get_data()];
                result[strKey] = s;
            } else if(val.get_type() == Variant::BOOL) {
                BOOL b = (bool)val;
                result[strKey] = @(b);
            } else if(val.get_type() == Variant::DICTIONARY) {
                NSDictionary *d = convertFromDictionary((Dictionary)val);
                result[strKey] = d;
            } else {
                ERR_PRINT("Unexpected type as dictionary value");
            }
        } else {
            ERR_PRINT("Non string key in Dictionary");
        }
    }
    return result;
}

GodotFacebook::GodotFacebook() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    initialized = false;
    callbackId = 0;
}

GodotFacebook::~GodotFacebook() {
    instance = NULL;
}


void GodotFacebook::init(const String &fbAppId){
    NSLog(@"GodotFacebook Module initialized");
    NSDictionary *launchOptions = @{};
    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
    didFinishLaunchingWithOptions:launchOptions];
    initialized = true;
}

void GodotFacebook::login(){
    NSLog(@"GodotFacebook Module login");
    if ([FBSDKAccessToken currentAccessTokenIsActive]){
        FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
        Object *obj = ObjectDB::get_instance(callbackId);
        obj->call_deferred(String("login_success"), [accessToken.tokenString UTF8String]);
    }else{
        [[[FBSDKLoginManager alloc] init] logInWithPublishPermissions: @[]
        fromViewController: [AppDelegate getViewController]
        handler: ^ (FBSDKLoginManagerLoginResult *result, NSError *error){
            Object *obj = ObjectDB::get_instance(callbackId);
            if (error != nil){
                obj->call_deferred(String("login_failed"), [error.localizedDescription UTF8String]);
            }else if (result.isCancelled){
                obj->call_deferred(String("login_cancelled"));
            }else{
                FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
                obj->call_deferred(String("login_success"), [accessToken.tokenString UTF8String]);
            }
        }];
    }
}

void GodotFacebook::logout(){
    NSLog(@"GodotFacebook Module logout");
    [[[FBSDKLoginManager alloc] init] logOut];
}

void GodotFacebook::setFacebookCallbackId(int cbackId){
    NSLog(@"GodotFacebook Module set callback id");
    callbackId = cbackId;
}

int GodotFacebook::getFacebookCallbackId(){
    NSLog(@"GodotFacebook Module get callback id");
    return callbackId;
}

void GodotFacebook::isLoggedIn(){
    NSLog(@"GodotFacebook Module is logged in");
    FBSDKAccessToken *accessToken = [FBSDKAccessToken currentAccessToken];
    Object *obj = ObjectDB::get_instance(callbackId);
    if ([FBSDKAccessToken currentAccessTokenIsActive]){
        obj->call_deferred(String("login_success"), [accessToken.tokenString UTF8String]);
    }else{
        if (accessToken == nil){
            obj->call_deferred(String("login_failed"), [@"No token" UTF8String]);
        }else{
            obj->call_deferred(String("login_failed"), [@"No expired" UTF8String]);
        }
    }
}

void GodotFacebook::shareLink(const String &url, const String &quote){
    NSLog(@"GodotFacebook Module share link content");
    FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
    content.quote = [NSString stringWithCString:quote.utf8().get_data() encoding: NSUTF8StringEncoding];
    content.contentURL = [NSURL URLWithString:[NSString stringWithCString:url.utf8().get_data() encoding: NSUTF8StringEncoding]];
    FBSDKShareDialog *shareDialog = [[FBSDKShareDialog alloc] init];
    shareDialog.fromViewController = [AppDelegate getViewController];
    shareDialog.shareContent = content;
    [shareDialog show];
}

void GodotFacebook::shareLinkWithoutQuote(const String &url){
    NSLog(@"GodotFacebook Module share link without quote");
    FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
    content.contentURL = [NSURL URLWithString:@"https://www.facebook.com/FacebookDevelopers"];
    FBSDKShareDialog *shareDialog = [[FBSDKShareDialog alloc] init];
    shareDialog.fromViewController = [AppDelegate getViewController];
    shareDialog.shareContent = content;
    [shareDialog show];
}

void GodotFacebook::sendEventWithParams(const String &eventName, const Dictionary& key_values) {
    [FBSDKAppEvents logEvent:[NSString stringWithCString:eventName.utf8().get_data() encoding: NSUTF8StringEncoding] parameters:convertFromDictionary(key_values)];
}

void GodotFacebook::sendEvent(const String &eventName) {
    [FBSDKAppEvents logEvent:[NSString stringWithCString:eventName.utf8().get_data() encoding: NSUTF8StringEncoding]];
}

void GodotFacebook::sendContentViewEvent(){
    [FBSDKAppEvents logEvent: FBSDKAppEventNameViewedContent];
}

void GodotFacebook::sendAchieveLevelEvent(const String &level){
    NSDictionary *params = @{ FBSDKAppEventParameterNameLevel : [NSString stringWithCString:level.utf8().get_data() encoding: NSUTF8StringEncoding] };
    [FBSDKAppEvents logEvent:FBSDKAppEventNameAchievedLevel parameters:params];
}

void GodotFacebook::_bind_methods() {
    ClassDB::bind_method("init",&GodotFacebook::init);
    ClassDB::bind_method("login",&GodotFacebook::login);
    ClassDB::bind_method("logout",&GodotFacebook::logout);
    ClassDB::bind_method("setFacebookCallbackId",&GodotFacebook::setFacebookCallbackId);
    ClassDB::bind_method("getFacebookCallbackId",&GodotFacebook::getFacebookCallbackId);
    ClassDB::bind_method("isLoggedIn",&GodotFacebook::isLoggedIn);
    ClassDB::bind_method("shareLink",&GodotFacebook::shareLink);
    ClassDB::bind_method("shareLinkWithoutQuote",&GodotFacebook::shareLinkWithoutQuote);
    ClassDB::bind_method("sendEvent", &GodotFacebook::sendEvent);
    ClassDB::bind_method("sendEventWithParams", &GodotFacebook::sendEventWithParams);
    ClassDB::bind_method("sendContentViewEvent", &GodotFacebook::sendContentViewEvent);
    ClassDB::bind_method("sendAchieveLevelEvent", &GodotFacebook::sendAchieveLevelEvent);
}
