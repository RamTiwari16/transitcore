using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PortalService.Infrastructure.Templates
{
    public static class EmailTemplates
    {
        
        public static string template(int ticketId, string issueTitle,string MachineSerialNo, string OwnerName, string MachineAddress, DateTime createdOn)
        {
                        return $@"
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body {{
                        font-family: Arial, sans-serif;
                        line-height: 1.6;
                        color: #333333;
                    }}
                    .container {{
                        max-width: 600px;
                        margin: 0 auto;
                        padding: 20px;
                        background-color: #f9f9f9;
                    }}
                    .header {{
                        background-color: #0066cc;
                        color: white;
                        padding: 20px;
                        text-align: center;
                        border-radius: 5px 5px 0 0;
                    }}
                    .content {{
                        background-color: white;
                        padding: 30px;
                        border-radius: 0 0 5px 5px;
                        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                    }}
                    .ticket-info {{
                        background-color: #f0f8ff;
                        padding: 15px;
                        margin: 20px 0;
                        border-left: 4px solid #0066cc;
                        border-radius: 3px;
                    }}
                    .info-row {{
                        margin: 10px 0;
                    }}
                    .label {{
                        font-weight: bold;
                        color: #0066cc;
                    }}
                    .footer {{
                        margin-top: 20px;
                        padding-top: 20px;
                        border-top: 1px solid #dddddd;
                        color: #666666;
                        font-size: 12px;
                    }}
                </style>
            </head>
            <body>
                <div class='container'>
                    <div class='header'>
                        <h2 style='margin: 0;'>New Support Ticket Created</h2>
                    </div>
                    <div class='content'>
                        <p>Dear Sir/Mam,</p>
            
                        <p>A new support ticket has been successfully created in the CDM system. Please find the details below:</p>
            
                        <div class='ticket-info'>
                            <div class='info-row'>
                                <span class='label'>Ticket ID:</span> #{ticketId}
                            </div>
                            <div class='info-row'>
                                <span class='label'>Issue Title:</span> {issueTitle}
                            </div>
                            <div class='info-row'>
                                <span class='label'>Machine Id:</span> {MachineSerialNo}
                            </div>
                            <div class='info-row'>
                                <span class='label'>Owner Name:</span> {OwnerName}
                            </div>
                            <div class='info-row'>
                                <span class='label'>Machine Address:</span> {MachineAddress}
                            </div>
                           
                            <div class='info-row'>
                                <span class='label'>Created On:</span> {createdOn:dd-MMM-yyyy hh:mm tt}
                            </div>
                        </div>
            
                        <p>Our support team will review your ticket and respond as soon as possible. You will receive updates via email as your ticket progresses.</p>
            
                        <p>If you have any urgent concerns, please contact our support team directly.</p>
            
                        <div class='footer'>
                            <p><strong>Best Regards,</strong><br/>
                            CDM Support Team</p>
                
                            <p style='font-size: 11px; color: #999999;'>
                                This is an automated message. Please do not reply directly to this email.
                            </p>
                        </div>
                    </div>
                </div>
            </body>
        </html>";
        }
    }
}
