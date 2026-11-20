import {createClient, type SupabaseClient} from '@supabase/supabase-js';
import type {AppRecord,Feedback} from './types';
const url=import.meta.env.VITE_SUPABASE_URL as string|undefined; const key=import.meta.env.VITE_SUPABASE_ANON_KEY as string|undefined;
export const supabase:SupabaseClient|null=url&&key?createClient(url,key):null;
const DEMO:AppRecord[]=[
{id:'demo-focusflow',name:'FocusFlow',description:'A calm, intelligent workspace that turns scattered thoughts into focused work sessions. Plan your day, protect deep-work time and see your momentum build.',url:'https://example.com',category:'Productivity',creator_name:'LaunchLoop Team',tech_stack:['React','TypeScript','Supabase'],screenshot_url:'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=1200',tags:['focus','workflow','productivity'],created_at:new Date().toISOString(),is_demo:true},
{id:'demo-pixelchef',name:'PixelChef',description:'Turn the ingredients already in your kitchen into something wonderful. A playful recipe discovery experience for curious home cooks.',url:'https://example.com',category:'Lifestyle',creator_name:'LaunchLoop Team',tech_stack:['Next.js','AI','Tailwind'],screenshot_url:'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=1200',tags:['food','recipes','AI'],created_at:new Date().toISOString(),is_demo:true},
{id:'demo-sprintboard',name:'SprintBoard',description:'A lightweight project command center for small teams. Make priorities visible, celebrate momentum and ship work without the noise.',url:'https://example.com',category:'Developer Tools',creator_name:'LaunchLoop Team',tech_stack:['Vue','Node.js'],screenshot_url:'https://images.unsplash.com/photo-1460925895917-afdad827c52f?w=1200',tags:['teams','project management','build'],created_at:new Date().toISOString(),is_demo:true}
];
const DEMO_FEEDBACK:Feedback[]=[{id:'df1',application_id:'demo-focusflow',type:'feature',rating:5,message:'Love the calm interface. A weekly focus report would make this even better.',created_at:new Date().toISOString(),is_demo:true},{id:'df2',application_id:'demo-focusflow',type:'bug',rating:3,message:'The timer can keep running after switching tabs on my phone.',created_at:new Date().toISOString(),is_demo:true},{id:'df3',application_id:'demo-pixelchef',type:'experience',rating:4,message:'Great idea and easy to use. Please add dietary filters.',created_at:new Date().toISOString(),is_demo:true}];
const read=(k:string)=>{try{return JSON.parse(localStorage.getItem(k)||'[]')}catch{return []}}; const write=(k:string,v:unknown)=>localStorage.setItem(k,JSON.stringify(v));
export const demoMode=!supabase;
export async function getCurrentUser(){if(!supabase)return null;const {data,error}=await supabase.auth.getUser();if(error&&error.name!=='AuthSessionMissingError')throw error;return data.user??null}
export async function getAccessToken(){if(!supabase)return null;const {data,error}=await supabase.auth.getSession();if(error)throw error;return data.session?.access_token??null}
export async function signIn(email:string,password:string){if(!supabase)throw new Error('Authentication is unavailable in local demo mode.');const {data,error}=await supabase.auth.signInWithPassword({email,password});if(error)throw error;return data.user}
export async function signUp(email:string,password:string,displayName:string){if(!supabase)throw new Error('Authentication is unavailable in local demo mode.');const {data,error}=await supabase.auth.signUp({email,password,options:{data:{display_name:displayName}}});if(error)throw error;return data}
export async function signOut(){if(!supabase)return;const {error}=await supabase.auth.signOut();if(error)throw error}
export async function getApps():Promise<AppRecord[]>{if(supabase){const {data,error}=await supabase.from('applications').select('*').eq('status','published').order('created_at',{ascending:false});if(error)throw error;return [...((data||[]) as AppRecord[]),...DEMO]}return [...read('ll_apps'),...DEMO]}
export async function getApp(id:string):Promise<AppRecord|null>{if(id.startsWith('demo-'))return DEMO.find(a=>a.id===id)||null;if(supabase){const {data,error}=await supabase.from('applications').select('*').eq('id',id).maybeSingle();if(error)throw error;return data as AppRecord|null}return read('ll_apps').find((a:AppRecord)=>a.id===id)||null}
export async function submitApp(input:Omit<AppRecord,'id'|'created_at'>):Promise<AppRecord>{if(supabase){const {is_demo,...payload}=input;const user=await getCurrentUser();if(!user)throw new Error('Sign in to publish an application.');const {data,error}=await supabase.from('applications').insert({...payload,user_id:user.id,status:'published'}).select().single();if(error)throw error;return data as AppRecord}const a={...input,id:crypto.randomUUID(),created_at:new Date().toISOString()};write('ll_apps',[a,...read('ll_apps')]);return a}


export async function updateApp(id:string,input:Omit<AppRecord,'id'|'created_at'>):Promise<AppRecord>{
  if(supabase){const {is_demo,user_id,...payload}=input;const {data,error}=await supabase.from('applications').update(payload).eq('id',id).select().single();if(error)throw error;return data as AppRecord}
  const updated={...input,id,created_at:read('ll_apps').find((a:AppRecord)=>a.id===id)?.created_at||new Date().toISOString()};
  write('ll_apps',read('ll_apps').map((a:AppRecord)=>a.id===id?updated:a));
  return updated;
}

export async function deleteApp(id:string){
  if(supabase){const {error}=await supabase.from('applications').delete().eq('id',id);if(error)throw error;return}
  write('ll_apps',read('ll_apps').filter((a:AppRecord)=>a.id!==id));
  write('ll_feedback',read('ll_feedback').filter((f:Feedback)=>f.application_id!==id));
  write('ll_events',read('ll_events').filter((e:any)=>e.application_id!==id));
}
export async function getFeedback(id:string):Promise<Feedback[]>{if(id.startsWith('demo-'))return [...read('ll_feedback').filter((f:Feedback)=>f.application_id===id),...DEMO_FEEDBACK.filter(f=>f.application_id===id)].sort((a,b)=>b.created_at.localeCompare(a.created_at));if(supabase){const {data,error}=await supabase.from('feedback').select('*').eq('application_id',id).order('created_at',{ascending:false});if(error)throw error;return data as Feedback[]}return read('ll_feedback').filter((f:Feedback)=>f.application_id===id)}
export async function submitFeedback(f:Omit<Feedback,'id'|'created_at'>):Promise<Feedback>{
  if(f.application_id.startsWith('demo-')||!supabase){const item={...f,is_demo:f.application_id.startsWith('demo-')?false:f.is_demo,id:crypto.randomUUID(),created_at:new Date().toISOString()};write('ll_feedback',[item,...read('ll_feedback')]);return item}
  const response=await fetch('/api/feedback',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({application_id:f.application_id,type:f.type,rating:f.rating,message:f.message})});
  const data=await response.json();if(!response.ok)throw new Error(data.error||'Feedback could not be saved.');return data as Feedback;
}
let memorySessionId:string|undefined;
function visitorSessionId(){try{let id=sessionStorage.getItem('ll_event_session');if(!id){id=crypto.randomUUID();sessionStorage.setItem('ll_event_session',id)}return id}catch{memorySessionId ||= crypto.randomUUID();return memorySessionId}}
export async function trackEvent(application_id:string,event_type:string){
  if(!['showcase_view','outbound_click'].includes(event_type))throw new Error('Unsupported event type.');
  const session_id=visitorSessionId();
  if(supabase){const response=await fetch('/api/events',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({application_id,event_type,session_id}),keepalive:true});if(!response.ok){const data=await response.json().catch(()=>({}));throw new Error(data.error||'Event could not be recorded.')}}
  else{const events=read('ll_events');if(events.some((e:any)=>e.application_id===application_id&&e.event_type===event_type&&e.session_id===session_id))return;events.push({application_id,event_type,session_id,created_at:new Date().toISOString()});write('ll_events',events)}
}
export async function getEvents(){if(supabase){const user=await getCurrentUser();if(!user)return [];const {data,error}=await supabase.from('application_events').select('*');if(error)throw error;return data||[]}return read('ll_events')}
