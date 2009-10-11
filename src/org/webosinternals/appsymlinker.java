package org.webosinternals;
import com.palm.luna.LSException;
import com.palm.luna.service.LunaServiceThread;
import com.palm.luna.service.ServiceMessage;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import org.json.JSONException;

public class appsymlinker extends LunaServiceThread {

    public appsymlinker() {

    }

    private int RunCommand(ServiceMessage servicemessage, String Command, String AppName) throws LSException, FileNotFoundException, IOException, JSONException, InterruptedException
    {
        try
        {
            Runtime theRuntime = Runtime.getRuntime();
            Process theProcess = theRuntime.exec("/var/tmp/mvapp.sh " + Command + " " + AppName);

            BufferedReader lChldProcOutStream = new BufferedReader(new InputStreamReader(theProcess.getInputStream()));
            String lChldProcOutPutStr = null;
            while ((lChldProcOutPutStr = lChldProcOutStream.readLine()) != null)
            {
                servicemessage.respond(lChldProcOutPutStr);
            }
            lChldProcOutStream.close();

            int exitValue = theProcess.waitFor();
            return exitValue;
        }
        catch (Exception ex)
        {
            servicemessage.respondError("ERROR", ex.toString());
            return -99;
        }
    }

    public void LinkApp(ServiceMessage servicemessage) throws LSException, FileNotFoundException, IOException, JSONException, InterruptedException
        {
            //Get Commandline args
            if (servicemessage.getJSONPayload().length() == 0) {
                servicemessage.respondError("ERROR","AppName name must be specified.");
                return;
            }
            String AppName = servicemessage.getJSONPayload().getString("AppName");

            //Extract batch file
            try
            {
                ExtractFile (servicemessage);
            }
            catch (Exception ex)
            {
                return;
            }

            try
            {
                servicemessage.respond("Linking application...");

                //Run Command
                int ReturnCode = RunCommand(servicemessage, "link", AppName);

                //Get Return Code
                switch (ReturnCode)
                {
                    case 0:
                        servicemessage.respond("Complete");
                        break;
                    case 10:
                        servicemessage.respondError("10", "AppName not supplied");
                        break;
                    case 11:
                        servicemessage.respondError("11", "Link already exists");
                        break;
                    case 12:
                        servicemessage.respondError("12", "App does not exist in VAR");
                        break;
                    case 13:
                        servicemessage.respondError("13", "Copy failed from VAR to MEDIA");
                        break;
                    case 14:
                        servicemessage.respondError("14", "Removing app from VAR failed");
                        break;
                }
            }
            catch (Exception ex)
            {
                return;
            }
        }

    public void UnLinkApp(ServiceMessage servicemessage) throws LSException, FileNotFoundException, IOException, JSONException, InterruptedException
        {
            //Get Commandline args
            if (servicemessage.getJSONPayload().length() == 0) {
                servicemessage.respondError("ERROR","AppName name must be specified.");
                return;
            }
            String AppName = servicemessage.getJSONPayload().getString("AppName");

            //Extract batch file
            try
            {
                ExtractFile (servicemessage);
            }
            catch (Exception ex)
            {
                return;
            }

            try
            {
                servicemessage.respond("Unlinking application...");

                //Run Command
                int ReturnCode = RunCommand(servicemessage, "unlink", AppName);

                //Get Return Code
                switch (ReturnCode)
                {
                    case 0:
                        servicemessage.respond("Complete");
                        break;
                    case 10:
                        servicemessage.respondError("20", "AppName not supplied");
                        break;
                    case 11:
                        servicemessage.respondError("21", "App doesn't exist in MEDIA");
                        break;
                    case 12:
                        servicemessage.respondError("22", "Tar restore failed");
                        break;
                    case 13:
                        servicemessage.respondError("23", "Copy failed");
                        break;
                    case 14:
                        servicemessage.respondError("24", "Remove failed");
                        break;
                }
            }
            catch (Exception ex)
            {
                return;
            }
        }

    public void ListApps(ServiceMessage servicemessage) throws LSException, FileNotFoundException, IOException, JSONException, InterruptedException
        {
            //Extract batch file
            try
            {
                ExtractFile (servicemessage);
            }
            catch (Exception ex)
            {
                return;
            }

            try
            {
                servicemessage.respond("Listing applications...");

                //Run Command
                RunCommand(servicemessage, "list", "");
            }
            catch (Exception ex)
            {
                return;
            }
        }

    public void ListMovedApps(ServiceMessage servicemessage) throws LSException, FileNotFoundException, IOException, JSONException, InterruptedException
        {
            //Extract batch file
            try
            {
                ExtractFile (servicemessage);
            }
            catch (Exception ex)
            {
                return;
            }

            try
            {
                servicemessage.respond("Listing applications...");

                //Run Command
                RunCommand(servicemessage, "listmoved", "");
            }
            catch (Exception ex)
            {
                return;
            }
        }

    private static void ExtractFile(ServiceMessage servicemessage) throws FileNotFoundException, IOException, LSException, InterruptedException
     {
        try
        {
            Runtime theRuntime = Runtime.getRuntime();
            Process theProcess = theRuntime.exec("/bin/rm -f /var/tmp/mvapp.sh");
            theProcess.waitFor();

            InputStream in = appsymlinker.class.getResourceAsStream("/org/webosinternals/resources/mvapp.sh");
            InputStreamReader isr = new InputStreamReader(in);
            BufferedReader br = new BufferedReader(isr);

            BufferedWriter fw = new BufferedWriter(new FileWriter("/var/tmp/mvapp.sh", true));

            String line;
            while ((line = br.readLine()) != null) {
                fw.write(line + "\n");
            }

            fw.close();

            theProcess = theRuntime.exec("/bin/chmod 755 /var/tmp/mvapp.sh");
            theProcess.waitFor();
        }
        catch (IOException ex)
        {
            servicemessage.respondError("ERROR",ex.toString());
            return;
        }
     }
}
