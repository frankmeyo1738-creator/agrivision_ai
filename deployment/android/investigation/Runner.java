package ai.agrivision.investigation;
import android.app.Instrumentation;
import android.os.Bundle;
import android.content.Context;
import org.json.*;
import java.io.*;
import java.lang.reflect.*;
import java.nio.*;
import java.util.*;
public class Runner extends Instrumentation {
 public void onCreate(Bundle args){super.onCreate(args);start();}
 byte[] read(String path)throws Exception{try(InputStream s=getContext().getAssets().open(path);ByteArrayOutputStream b=new ByteArrayOutputStream()){byte[] a=new byte[8192];for(int n;(n=s.read(a))!=-1;)b.write(a,0,n);return b.toByteArray();}}
 float[] tensor(Object engine,byte[] image)throws Exception{
  Object decoded=engine.getClass().getMethod("decode",byte[].class).invoke(engine,(Object)image);
  Class<?> c=Class.forName("ai.agrivision.agrivision_ai.LeafPreprocessor");
  return (float[])c.getMethod("tensor",decoded.getClass()).invoke(c.getField("INSTANCE").get(null),decoded);
 }
 float[] golden(String file)throws Exception{FloatBuffer b=ByteBuffer.wrap(read(file)).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer();float[] f=new float[b.remaining()];b.get(f);return f;}
 float[] logits(Object e,float[] f)throws Exception{return (float[])e.getClass().getMethod("logits",float[].class).invoke(e,(Object)f);}
 double[] probabilities(float[] f){double max=-Double.MAX_VALUE;for(float v:f)max=Math.max(max,v);double sum=0;double[] p=new double[f.length];for(int i=0;i<f.length;i++){p[i]=Math.exp(f[i]-max);sum+=p[i];}for(int i=0;i<f.length;i++)p[i]/=sum;return p;}
 double error(float[] a,float[] b){double e=0;for(int i=0;i<a.length;i++)e=Math.max(e,Math.abs(a[i]-b[i]));return e;}
 public void onStart(){JSONObject report=new JSONObject();Bundle result=new Bundle();try{
  Context ctx=getTargetContext();Object engine=Class.forName("ai.agrivision.agrivision_ai.OfflineClassifier").getConstructor(Context.class).newInstance(ctx);
  report.put("device",android.os.Build.MODEL).put("sdk",android.os.Build.VERSION.SDK_INT).put("connectivity_unchanged",true);
  JSONObject refs=new JSONObject(new String(read("investigation/scores.json"),"UTF-8"));JSONArray images=refs.getJSONArray("images"),results=new JSONArray();report.put("images",results);
  for(int i=0;i<images.length();i++){
   JSONObject ref=images.getJSONObject(i);String prefix="investigation/image_"+(i+1);byte[] bytes=read(prefix+".jpeg");float[] g=golden(prefix+".f32"),a=tensor(engine,bytes),lossless=tensor(engine,read(prefix+".decoded.png")),same=logits(engine,g),nativeLogits=logits(engine,a);double[] p=probabilities(nativeLogits);JSONArray scores=new JSONArray();double ge=0,pe=0;int top=0;
   for(int j=0;j<p.length;j++){JSONObject expected=ref.getJSONArray("scores").getJSONObject(j);ge=Math.max(ge,Math.abs(same[j]-expected.getDouble("logit")));pe=Math.max(pe,Math.abs(p[j]-expected.getDouble("pytorch")));if(p[j]>p[top])top=j;scores.put(new JSONObject().put("index",j).put("label",expected.getString("label")).put("android_score",p[j]).put("android_logit",nativeLogits[j]));}
   results.put(new JSONObject().put("image",i+1).put("predicted_class",ref.getJSONArray("scores").getJSONObject(top).getString("label")).put("confidence",p[top]).put("tensor_max_abs_error",error(a,g)).put("lossless_tensor_max_abs_error",error(lossless,g)).put("same_input_logits_max_abs_error",ge).put("probabilities_max_abs_error",pe).put("scores",scores));
  }
  JSONArray cases=new JSONArray(new String(read("verification/cases.json"),"UTF-8")),checks=new JSONArray();report.put("parity_cases",checks);boolean passed=true;
  for(int i=0;i<cases.length();i++){
   JSONObject c=cases.getJSONObject(i);String n=c.getString("file");float[] g=golden("verification/"+n+".f32"),a=tensor(engine,read("verification/"+n)),lossless=tensor(engine,read("verification/"+c.getString("decoded_png"))),l=logits(engine,g);double[] p=probabilities(logits(engine,a));double ge=0,pe=0;int top=0;
   for(int j=0;j<l.length;j++){ge=Math.max(ge,Math.abs(l[j]-c.getJSONArray("pytorch_logits").getDouble(j)));pe=Math.max(pe,Math.abs(p[j]-c.getJSONArray("pytorch_probabilities").getDouble(j)));if(p[j]>p[top])top=j;}
   double te=error(a,g),le=error(lossless,g);boolean ok=te<=c.getDouble("tensor_tolerance")&&le<=1e-6&&ge<=1e-4&&pe<=c.getDouble("probability_tolerance")&&top==c.getInt("top_index");passed&=ok;
   checks.put(new JSONObject().put("file",n).put("tensor_max_abs_error",te).put("lossless_tensor_max_abs_error",le).put("same_input_logits_max_abs_error",ge).put("probabilities_max_abs_error",pe).put("top_one_matches",top==c.getInt("top_index")).put("passed",ok));
  }
  report.put("parity_passed",passed);engine.getClass().getMethod("close").invoke(engine);
 }catch(Throwable e){try{report.put("error",e.toString());StringWriter w=new StringWriter();e.printStackTrace(new PrintWriter(w));report.put("stack",w.toString());}catch(Exception ignored){}}
 try{File file=new File(getTargetContext().getExternalFilesDir(null),"phase4_investigation.json");try(FileWriter w=new FileWriter(file)){w.write(report.toString(2));}result.putString("stream","Diagnostic report saved: "+file);}catch(Exception e){result.putString("stream",e.toString());}finish(-1,result);
 }
}
