using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Widget;
using System.Text;
using CommunityToolkit.Mvvm.Messaging;

using Android.Content;
using Android.Util;
using Android.Views;
using Symbol.XamarinEMDK;
using System.Xml;
using Android.Database;
using static AndroidX.Core.Content.PM.PermissionInfoCompat;
using Android.Provider;


//https://learn.microsoft.com/en-us/dotnet/maui/platform-integration/native-embedding?view=net-maui-7.0
//https://learn.microsoft.com/it-it/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-7.0
//==> DEPRECATED//https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/messagingcenter?view=net-maui-7.0
//USE THIS // https://learn.microsoft.com/en-us/windows/communitytoolkit/mvvm/messenger

namespace emdkMAUIapp;

[Activity(Theme = "@style/Maui.SplashTheme", MainLauncher = true, ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation | ConfigChanges.UiMode | ConfigChanges.ScreenLayout | ConfigChanges.SmallestScreenSize | ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity, EMDKManager.IEMDKListener, EMDKManager.IStatusListener
{
    private EMDKManager emdkManager;
    private ProfileManager profileManager = null;
    StringBuilder sb;
    private Symbol.XamarinEMDK.Notification.NotificationManager notificationManager;

    

    void EMDKManager.IEMDKListener.OnClosed()
    {
        if (emdkManager != null)
        {
            emdkManager.Release();
        }
    }

    protected override void OnDestroy()
    {
        base.OnDestroy();

        // Clean up the objects created by EMDK manager
        if (profileManager != null)
        {
            profileManager = null;
        }

        if (emdkManager != null)
        {
            emdkManager.Release();
            emdkManager = null;
        }
    }

    void EMDKManager.IEMDKListener.OnOpened(EMDKManager emdkManagerInstance)
    {

        this.emdkManager = emdkManagerInstance;

        try
        {
            emdkManager.GetInstanceAsync(EMDKManager.FEATURE_TYPE.Profile, this);
            emdkManager.GetInstanceAsync(EMDKManager.FEATURE_TYPE.Version, this);
            emdkManager.GetInstanceAsync(EMDKManager.FEATURE_TYPE.Notification, this);
        }
        catch (Exception e)
        {
            //RunOnUiThread(() => statusTextView.Text = e.Message);
            Console.WriteLine("Exception: " + e.StackTrace);
        }
    }

    void EMDKManager.IStatusListener.OnStatus(EMDKManager.StatusData statusData, EMDKBase emdkBase)
    {
        if (statusData.Result == EMDKResults.STATUS_CODE.Success)
        {
            if (statusData.FeatureType == EMDKManager.FEATURE_TYPE.Profile)
            {
                profileManager = (ProfileManager)emdkBase;
                profileManager.Data += ProfileManager_Data;
                string[] modifyData = new string[1];
                EMDKResults results = profileManager.ProcessProfileAsync("SOMESETTING", ProfileManager.PROFILE_FLAG.Set, modifyData);
                sb.AppendLine("ProcessProfileAsync:" + results.StatusCode);

            }            
            
            if (statusData.FeatureType == EMDKManager.FEATURE_TYPE.Version)
            {
                versionManager = (VersionManager)emdkBase;
                String emdkVersion = versionManager.GetVersion(VersionManager.VERSION_TYPE.Emdk);
                String mxVersion = versionManager.GetVersion(VersionManager.VERSION_TYPE.Mx);
                sb.AppendLine("Versions: EMDK=" +emdkVersion+" MX="+mxVersion );

            }
            
            if (statusData.FeatureType == EMDKManager.FEATURE_TYPE.Notification)
            {
                notificationManager = (Symbol.XamarinEMDK.Notification.NotificationManager)emdkBase;

                foreach(Symbol.XamarinEMDK.Notification.DeviceInfo di in notificationManager.SupportedDevicesInfo)
                    sb.AppendLine("Notifications info: NAME=" + di.FriendlyName + " TYPE="+ di.DeviceType);

            }

        }
    }

    void ProfileManager_Data(object sender, ProfileManager.DataEventArgs e)
    {
        EMDKResults results = e.P0.Result;
        sb.AppendLine("onData:" + CheckXmlError(results));
        sb.AppendLine("Final Display TO: " + QueryAndroidSystemSettings(Settings.System.GetUriFor(Settings.System.ScreenOffTimeout)) +"msec" );
        long end_time = DateTime.Now.Ticks;
        sb.AppendLine("Time spent: " + (end_time-begin_time)/10000 +"msec" );


        //var toast = Toast.MakeText(this, sb.ToString(), ToastLength.Long);
        //toast.Show();

        WeakReferenceMessenger.Default.Send(sb.ToString());
    }


    protected override void OnCreate(Bundle savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        sb = new StringBuilder();


        //RECEIVING A STRING FROM XAML AND EXECUTING IN NATIVE ANDROID
        WeakReferenceMessenger.Default.Register<string>(this, (r, m) =>
        {
            //MainThread.BeginInvokeOnMainThread(() => {
                var toast = Toast.MakeText(this, "weakToast<"+m+">", ToastLength.Short);
                //toast.Show();
            //});
        });

        

    }

    public VersionManager versionManager { get; private set; }
    long begin_time= 0;
    protected override void OnPostCreate(Bundle savedInstanceState)
    {
        base.OnPostCreate(savedInstanceState);
        begin_time = DateTime.Now.Ticks;

        //adb shell content query --uri content://settings/system/screen_off_timeout
        sb.AppendLine("Initial Display TO: " + QueryAndroidSystemSettings(Settings.System.GetUriFor(Settings.System.ScreenOffTimeout)) + "msec");


        // The EMDKManager object will be created and returned in the callback
        EMDKResults results = EMDKManager.GetEMDKManager(this, this);
        sb.AppendLine("GetEMDKManager:" + results.StatusCode);
    }

    String QueryAndroidSystemSettings(Android.Net.Uri uri) { //e.g."content://settings/system/screen_off_timeout"
        string[] projection = new string[] { "name" };
        //Android.Net.Uri.Builder _ub = new Android.Net.Uri.Builder();
        //Android.Net.Uri uri = _ub.Path(key).Build();
        ICursor syssetCursor = ContentResolver.Query(uri, null, null, null, null);

        string text = "";
        if (syssetCursor.MoveToFirst())
        {
            text = syssetCursor.GetString(2);
        }
        return text;

    }


    private string CheckXmlError(EMDKResults results)
    {
        StringReader stringReader = null;
        string checkXmlStatus = "";
        bool isFailure = false;

        try
        {
            if (results.StatusCode == EMDKResults.STATUS_CODE.CheckXml)
            {
                stringReader = new StringReader(results.StatusString);

                using (XmlReader reader = XmlReader.Create(stringReader))
                {
                    while (reader.Read())
                    {
                        if (reader.NodeType == XmlNodeType.Element)
                        {
                            switch (reader.Name)
                            {
                                case "parm-error":
                                    isFailure = true;
                                    string parmName = reader.GetAttribute("name");
                                    string parmErrorDescription = reader.GetAttribute("desc");
                                    checkXmlStatus = "Name: " + parmName + ", Error Description: " + parmErrorDescription;
                                    break;
                                case "characteristic-error":
                                    isFailure = true;
                                    string errorType = reader.GetAttribute("type");
                                    string charErrorDescription = reader.GetAttribute("desc");
                                    checkXmlStatus = "Type: " + errorType + ", Error Description: " + charErrorDescription;
                                    break;
                            }
                        }
                    }

                    if (!isFailure)
                    {
                        checkXmlStatus = "Profile applied successfully ...";
                    }

                }
            }
            else
            {
                checkXmlStatus = results.StatusCode.ToString();
            }
        }
        finally
        {
            if (stringReader != null)
            {
                stringReader.Dispose();
            }
        }

        return checkXmlStatus;
    }


}
