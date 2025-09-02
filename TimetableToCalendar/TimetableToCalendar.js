javascript:(()=>{ 
  const requiredURL="https://fap.fpt.edu.vn/Report/ViewAttendstudent.aspx";
  if(!location.href.startsWith(requiredURL)){
    if(confirm("Script chỉ chạy ở trang ViewAttendstudent.\nBạn có muốn chuyển đến trang đó không?")){
      location.href=requiredURL;
    }
    return;
  }

  const TZID='Asia/Ho_Chi_Minh';
  const q=(s,r=document)=>r.querySelector(s);
  const qa=(s,r=document)=>Array.from(r.querySelectorAll(s));
  const sanitizeFilename=s=>(s||'course').replace(/[<>:"/\\|?*\u0000-\u001F]+/g,' ').replace(/\s+/g,' ').trim()+'.ics';
  const escICS=(s='')=>String(s).replace(/\\/g,'\\\\').replace(/;/g,'\\;').replace(/,/g,'\\,').replace(/\n/g,'\\n');
  const pad2=n=>String(n).padStart(2,'0');
  const fmtICSLocal=d=>`${d.getFullYear()}${pad2(d.getMonth()+1)}${pad2(d.getDate())}T${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
  const fmtICSStampUTC=(d=new Date())=>`${d.getUTCFullYear()}${pad2(d.getUTCMonth()+1)}${pad2(d.getUTCDate())}T${pad2(d.getUTCHours())}${pad2(d.getUTCMinutes())}${pad2(d.getUTCSeconds())}Z`;

  let selectedCourseEl=q('#ctl00_mainContent_divCourse b')||qa('#ctl00_mainContent_divCourse td').find(td=>!td.querySelector('a')&&td.textContent.trim());
  if(!selectedCourseEl){alert('Hãy chọn 1 môn ở cột Course trước khi export.');return;}
  const courseNameRaw=selectedCourseEl.textContent.trim();

  let courseCode=null;const parenMatches=[];
  courseNameRaw.replace(/\(([^)]+)\)/g,(_,inner)=>parenMatches.push(inner.trim()));
  for(const p of parenMatches){if(/^[A-Za-z]{2,}\d+[A-Za-z]*$/i.test(p)&&!/^SE\d+/i.test(p)&&!p.includes('_')){courseCode=p;break;}}
  if(!courseCode){const m=courseNameRaw.match(/[A-Za-z]{2,}\d+[A-Za-z]*/);if(m)courseCode=m[0];}
  const summaryBase=courseCode||courseNameRaw;

  const rows=qa('table.table1 tbody tr').filter(tr=>tr.children.length>=7);
  if(!rows.length){alert('Không tìm thấy hàng lịch trong bảng .table1.');return;}

  const events=[];
  rows.forEach((tr,idx)=>{
    const tds=tr.querySelectorAll('td');if(tds.length<7)return;
    const no=tds[0].textContent.trim();
    const dateText=tds[1].textContent.trim();
    const slotText=tds[2].textContent.trim();
    const room=tds[3].textContent.trim();
    const lecturer=tds[4].textContent.trim();
    const groupName=tds[5].textContent.trim();
    const dm=dateText.match(/(\d{2})\/(\d{2})\/(\d{4})/);if(!dm)return;
    const dd=+dm[1],mm=+dm[2],yyyy=+dm[3];
    const sm=slotText.match(/\((\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})\)/);if(!sm)return;
    const[sh,smm]=sm[1].split(':').map(Number);const[eh,emm]=sm[2].split(':').map(Number);
    const start=new Date(yyyy,mm-1,dd,sh,smm,0);
    const end=new Date(yyyy,mm-1,dd,eh,emm,0);
    events.push({no,start,end,room,lecturer,groupName});
  });

  if(!events.length){alert('Không parse được buổi học nào từ bảng lịch.');return;}

  const dtstamp=fmtICSStampUTC(new Date());
  const vtimezone=['BEGIN:VTIMEZONE','TZID:'+TZID,'X-LIC-LOCATION:Asia/Ho_Chi_Minh','BEGIN:STANDARD','TZOFFSETFROM:+0700','TZOFFSETTO:+0700','TZNAME:+07','DTSTART:19700101T000000','END:STANDARD','END:VTIMEZONE'].join('\r\n');
  const header=['BEGIN:VCALENDAR','PRODID:-//FAP Export//Console Script//VN','VERSION:2.0','CALSCALE:GREGORIAN','METHOD:PUBLISH',`NAME:${escICS(summaryBase)}`,`X-WR-CALNAME:${escICS(summaryBase)}`,`X-WR-TIMEZONE:${TZID}`].join('\r\n');

  const body=events.map((ev,idx)=>{
    const uid=`${ev.start.getFullYear()}${pad2(ev.start.getMonth()+1)}${pad2(ev.start.getDate())}-${pad2(ev.start.getHours())}${pad2(ev.start.getMinutes())}-${idx}@fap-export`;
    const summary=`${summaryBase} - Slot ${ev.no||'?'}`;
    const desc=[`Lecturer: ${ev.lecturer||''}`,`Group: ${ev.groupName||''}`].filter(Boolean).join('\n');
    return['BEGIN:VEVENT',`UID:${uid}`,`DTSTAMP:${dtstamp}`,`DTSTART;TZID=${TZID}:${fmtICSLocal(ev.start)}`,`DTEND;TZID=${TZID}:${fmtICSLocal(ev.end)}`,`SUMMARY:${escICS(summary)}`,ev.room?`LOCATION:${escICS(ev.room)}`:null,desc?`DESCRIPTION:${escICS(desc)}`:null,'END:VEVENT'].filter(Boolean).join('\r\n');
  }).join('\r\n');

  const ics=[header,vtimezone,body,'END:VCALENDAR'].join('\r\n');
  const fileName=sanitizeFilename(summaryBase);
  const blob=new Blob([ics],{type:'text/calendar;charset=utf-8'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;a.download=fileName;
  document.body.appendChild(a);a.click();
  setTimeout(()=>{document.body.removeChild(a);URL.revokeObjectURL(url);},0);
  console.log(`Exported ${events.length} events. File: ${fileName}`);
})();
