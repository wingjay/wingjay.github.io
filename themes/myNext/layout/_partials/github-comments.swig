<!doctype html>
<html>
<div class="clearfix"></div>
<br>
<div id="comments">
<div class="post-header bg-{{site.default_post_color}}">
  <h1 class="h1 post-title">评论</h1>
</div>

<article class="post-content">
<p>本站评论搭建在 Github Issue 上，请前往 <a href="https://github.com/wingjay/wingjay.github.io/issues/1/{{page.commentIssueId}}">  此文issue</a> 进行评论。（你需要有 Github 账号）<br/>
Want to leave a comment? Visit <a href="https://github.com/wingjay/wingjay.github.io/issues/1/{{page.commentIssueId}}"> this post's issue page on GitHub</a> (you'll need a GitHub account).</p>
</article>
</div>

<style type="text/css">
.timeline-comment-wrapper {
    margin-top: 0;
    position: relative;
    padding-left: 60px;
    margin-top: 15px;
    margin-bottom: 15px;
    border-top: 2px solid #fff;
    border-bottom: 2px solid #fff;
}
.timeline-comment-avatar {
    float: left;
    margin-left: -60px;
    border-radius: 3px;
}
.avatar-parent-child {
    position: relative;
}
.timeline-comment-wrapper a {
    color: #0366d6;
    text-decoration: none;
    background-color: transparent;
}
.timeline-comment-wrapper .avatar {
    display: inline-block;
    overflow: hidden;
    line-height: 1;
    vertical-align: middle;
    border-radius: 3px;
}
.timeline-comment-wrapper .rounded-1 {
    border-radius: 3px !important;
}
.timeline-comment.current-user {
    border-color: #c0d3eb;
}
.timeline-comment {
	position: relative;
    background-color: #fff;
    border: 1px solid #d1d5da;
    border-radius: 3px;
}
.timeline-comment.current-user .timeline-comment-header {
    background-color: #f1f8ff;
    border-bottom-color: #c0d3eb;
}
.timeline-comment-header {
	padding-right: 15px;
    padding-left: 15px;
    color: #586069;
    background-color: #f6f8fa;
    border-bottom: 1px solid #d1d5da;
    border-top-left-radius: 3px;
    border-top-right-radius: 3px;
}
.timeline-comment-header-text {
    padding-top: 10px;
    padding-bottom: 10px;
}
.timeline-comment-header h3 {
    margin-top: 0px;
    margin-bottom: 0px;
}
.timeline-comment-header-text .post-meta {
	margin-left: 6px;
}
.timeline-comment article p {
	margin: 0px;
}
.text-normal {
    font-weight: normal !important;
}
.f5 {
    font-size: 14px !important;
}
.submit-comment .btn {
    position: relative;
    display: inline-block;
    padding: 6px 12px;
    font-size: 14px;
    font-weight: 600;
    line-height: 20px;
    white-space: nowrap;
    vertical-align: middle;
    cursor: pointer;
    -webkit-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    user-select: none;
    background-repeat: repeat-x;
    background-position: -1px -1px;
    background-size: 110% 110%;
    border: 1px solid rgba(27,31,35,0.2);
    border-radius: 0.25em;
    -webkit-appearance: none;
    -moz-appearance: none;
    appearance: none;
}
.submit-comment .btn-primary {
    color: #fff;
    background-color: #28a745;
    background-image: -webkit-linear-gradient(270deg, #34d058 0%, #28a745 90%);
    background-image: linear-gradient(-180deg, #34d058 0%, #28a745 90%);
}
</style>

<script type="text/javascript">
  function loadComments(data) {
  	var commentUrl = "location.href='https://github.com/wingjay/wingjay.github.io/issues/{{ page.commentIssueId }}'"
    $("#comments").append('<div class="submit-comment" style="text-align: center"><button onclick=' + commentUrl + ' class="btn btn-primary">评论</button></div>')

    for (var i=0; i<data.length; i++) {
      var cuser = data[i].user.login;
      var cuserlink = data[i].user.html_url;
      var avatarlink = data[i].user.avatar_url;
      var clink = data[i].html_url;
      var cbody = data[i].body_html;
      var cavatarlink = data[i].user.avatar_url;      
      var cdate = new Date(data[i].created_at);
      var dopts = { month: 'short', day: 'numeric', year: 'numeric' }

      $("#comments").append('<div class="timeline-comment-wrapper"><div class="avatar-parent-child timeline-comment-avatar"><a href="' + cuserlink +'"><img width="44" height="44" class="avatar rounded-1" src="' + avatarlink + '"></a></div><div class="timeline-comment current-user"><div class="timeline-comment-header"><h3 class="timeline-comment-header-text text-normal f5"><strong>' + cuser + '</strong><span class="post-meta">' + cdate.toLocaleDateString("en", dopts) + '</span></h3></div><div style="display: block !important; padding: 15px;"><article class="post-content">' + cbody + '</article></div></div></div>');
    }
  }
  $.ajax("https://api.github.com/repos/wingjay/wingjay.github.io/issues/{{ page.commentIssueId }}/comments", {
    headers: {Accept: "application/vnd.github.v3.html+json"},
    dataType: "json",
    success: function(msg){
      console.log(msg);
      loadComments(msg);
   }
  });
</script>
</html>
