package heroku

import (
	"github.com/bgentry/testnet"
	"testing"
)

//
// AppInfo()
//

const appInfoResponseBody = `{
	"archived_at": "2012-01-01T12:00:00Z",
	"buildpack_provided_description": "Ruby/Rack",
	"created_at": "2012-01-01T12:00:00Z",
	"git_url": "git@heroku.com/example.git",
	"id": "01234567-89ab-cdef-0123-456789abcdef",
	"maintenance": true,
	"name": "example",
	"owner": {
		"email": "username@example.com",
		"id": "01234567-89ab-cdef-0123-456789abcdef"
	},
	"region": {
		"id": "01234567-89ab-cdef-0123-456789abcdef",
		"name": "us"
	},
	"released_at": "2012-01-01T12:00:00Z",
	"repo_size": 1,
	"slug_size": 1,
	"stack": {
		"id": "01234567-89ab-cdef-0123-456789abcdef",
		"name": "cedar"
	},
	"updated_at": "2012-01-01T12:00:00Z",
	"web_url": "http://example.herokuapp.com"
}`

var appInfoResponse = testnet.TestResponse{
	Status: 200,
	Body:   appInfoResponseBody,
}
var appInfoRequest = newTestRequest("GET", "/apps/example", "", appInfoResponse)

func TestAppInfoSuccess(t *testing.T) {
	ts, handler, c := newTestServerAndClient(t, appInfoRequest)
	defer ts.Close()

	app, err := c.AppInfo("example")
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
	if app == nil {
		t.Fatal("no app object returned")
	}
	testStringsEqual(t, "app.Name", "example", app.Name)
	testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
	testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
}

//
// AppCreate()
//

const appCreateRequestBody = `{
	"name":"example",
	"region": "us",
	"stack": "cedar"
}`

var appCreateResponse = testnet.TestResponse{
	Status: 201,
	Body:   appInfoResponseBody,
}
var appCreateRequest = newTestRequest("POST", "/apps", appCreateRequestBody, appCreateResponse)

func TestAppCreateSuccess(t *testing.T) {
	ts, handler, c := newTestServerAndClient(t, appCreateRequest)
	defer ts.Close()

	app, err := c.AppCreate("example", "us", "cedar")
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
	if app == nil {
		t.Fatal("no app object returned")
	}
	testStringsEqual(t, "app.Name", "example", app.Name)
	testStringsEqual(t, "app.Region.Name", "us", app.Region.Name)
	testStringsEqual(t, "app.Stack.Name", "cedar", app.Stack.Name)
}

//
// AppDelete()
//

var appDeleteResponse = testnet.TestResponse{
	Status: 200,
	Body:   appInfoResponseBody,
}
var appDeleteRequest = newTestRequest("DELETE", "/apps/example", "", appDeleteResponse)

func TestAppDeleteSuccess(t *testing.T) {
	ts, handler, c := newTestServerAndClient(t, appDeleteRequest)
	defer ts.Close()

	err := c.AppDelete("example")
	if err != nil {
		t.Fatal(err)
	}
	if !handler.AllRequestsCalled() {
		t.Errorf("not all expected requests were called")
	}
}
