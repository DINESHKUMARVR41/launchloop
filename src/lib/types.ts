export type AppRecord={id:string;name:string;description:string;url:string;category:string;creator_name:string;tech_stack:string[];screenshot_url:string;tags:string[];created_at:string;user_id?:string|null;is_demo?:boolean;};
export type Feedback={id:string;application_id:string;type:string;rating:number;message:string;created_at:string;is_demo?:boolean;};
