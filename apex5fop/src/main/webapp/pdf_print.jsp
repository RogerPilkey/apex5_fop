<%--
    Document   : pdf_print.jsp
    Created on : Feb 12, 2016, 8:55:39 AM
    Author     : Mikhail Mikhailidi
    Mangled by Roger Pilkey, 2017-07-28, for fop 2.2
    updated by Roger Pilkey, 2020-05-27, for fop 2.5
--%>
<%@ page trimDirectiveWhitespaces="true" %>
<%@ page import='java.io.*' %>
<%@ page import='org.apache.fop.apps.Fop' %>
<%@ page import='org.apache.fop.apps.FopFactory' %>
<%@ page import='org.apache.fop.apps.FopFactoryBuilder' %>
<%@ page import='org.apache.fop.apps.FOUserAgent' %>
<%@ page import='org.apache.fop.apps.MimeConstants' %>
<%@ page import='javax.xml.transform.Result' %>
<%@ page import='javax.xml.transform.Source' %>
<%@ page import='javax.xml.transform.sax.SAXResult' %>
<%@ page import='javax.xml.transform.TransformerFactory' %>
<%@ page import='javax.xml.transform.Transformer' %>
<%@ page import='javax.xml.transform.stream.StreamSource' %>
<%

// original: https://xmlgraphics.apache.org/fop/2.2/servlets.html
//private TransformerFactory tFactory = TransformerFactory.newInstance();
// RP: above line causes an error. ok, so try not private...
TransformerFactory tFactory = TransformerFactory.newInstance();

// customize userAgent
String accessibleparam = request.getParameter("accessible");
FopFactory fopFactory;
FOUserAgent userAgent;

//if no accessible parameter, don't use the conf file
if (accessibleparam==null || accessibleparam.isEmpty()) {
    // (reuse if you plan to render multiple documents!)
    // RP: I think this would be reused if rendering multiple files, by putting it in a jsp declaration (<%!...) but it doesn't seem to matter here where we do one at a time
    fopFactory = FopFactory.newInstance(new File(request.getServletContext().getRealPath("fop.normal.conf")));

    // do the following for each new rendering run
    userAgent = fopFactory.newFOUserAgent();
    userAgent.setAccessibility(false);

}else{
    
    //RP 2020-06-24: can't depend on this folder working, it's different on linux and windows, or maybe there's some alias or mapping going on
    //fopFactory = FopFactory.newInstance(new File("webapps/fop/fop.accessible.conf"));
    fopFactory = FopFactory.newInstance(new File(request.getServletContext().getRealPath("fop.accessible.conf")));

    // do the following for each new rendering run
    userAgent = fopFactory.newFOUserAgent();
    //RP: setting accessibility in conf file seems to be ignored...so set it in the userAgent
    userAgent.setAccessibility(true);

    // PDF/UA-1 is better (passes PAC(!)), but fails and dies if input doesn't have all the metadata properties ...like the builtin IR download call , yay
    // FOP's PDF/A-1a output is tagged, but lots of artifacts, and doesn't have good metadata. works with Apex IR download, but fop doesn't include good stuff like it does for pdf/ua-1, nice (A for Archival quality)

    if (accessibleparam.equals("PDF/UA-1")){
        userAgent.getRendererOptions().put("pdf-ua-mode", "PDF/UA-1");
    }else{
        userAgent.getRendererOptions().put("pdf-ua-mode", "PDF/A-1a");
    }

}
//use our custom eventlistener to print info/warn/error/fatal messages (?)
userAgent.getEventBroadcaster().addEventListener(new SysOutEventListener());

//Setup a buffer to obtain the content length
ByteArrayOutputStream v_out = new ByteArrayOutputStream();

//Setup FOP
//RP: MimeConstants.MIME_PDF cannot resolve ? Solution: make sure all fop/lib. jar files are in lib/ and restart Tomcat.
Fop fop;
String mimetype = (request.getParameter("mimetype") != null) ? request.getParameter("mimetype") : "null";
switch (mimetype) {
    case "RTF":
        fop = fopFactory.newFop(MimeConstants.MIME_RTF, userAgent, v_out);
        break;
    case "PLAIN_TEXT":
        fop = fopFactory.newFop(MimeConstants.MIME_PLAIN_TEXT, userAgent, v_out);
        break;
    default: //default to PDF
        fop = fopFactory.newFop(MimeConstants.MIME_PDF, userAgent, v_out);
        break;
    }
//Setup Transformer
Source xsltSrc = new StreamSource( new java.io.StringReader(request.getParameter("template")));

Transformer transformer = tFactory.newTransformer(xsltSrc);

//Make sure the XSL transformation's result is piped through to FOP
Result res = new SAXResult(fop.getDefaultHandler());

//Setup input
Source src = new StreamSource(new java.io.StringReader(request.getParameter("xml")));

//Start the transformation and rendering process
transformer.transform(src, res);

//Prepare response
switch (mimetype){
    case "RTF":
        response.setContentType(MimeConstants.MIME_RTF);
        break;
    case "PLAIN_TEXT":
        response.setContentType(MimeConstants.MIME_PLAIN_TEXT);
        break;
    default: //default to PDF
        response.setContentType(MimeConstants.MIME_PDF);
        break;
    }

response.setContentLength(v_out.size());

//Send content to Browser
response.getOutputStream().write(v_out.toByteArray());
response.getOutputStream().flush();
response.getOutputStream().close();
%>
